"""Export the upstream fused Gaze360 MobileOne S0 checkpoint to Core ML."""
import argparse
import hashlib
import json
import logging
from pathlib import Path

import coremltools as ct
import numpy as np
import torch
from PIL import Image
from vendor.mobileone import mobileone_s0

logging.getLogger().setLevel(logging.WARNING)

ROOT = Path(__file__).resolve().parent


class Gaze(torch.nn.Module):
    def __init__(self, backbone):
        super().__init__()
        self.backbone = backbone
        self.register_buffer('mean', torch.tensor([0.485, 0.456, 0.406]).view(1, 3, 1, 1))
        self.register_buffer('std', torch.tensor([0.229, 0.224, 0.225]).view(1, 3, 1, 1))
        self.register_buffer('bins', torch.arange(90, dtype=torch.float32))

    def forward(self, face):
        yaw, pitch = self.backbone((face / 255.0 - self.mean) / self.std)
        # Gaze360 expected bin index -> degrees -> radians, matching upstream.
        yaw = ((yaw.softmax(-1) * self.bins).sum(-1) * 4 - 180) * (np.pi / 180)
        pitch = ((pitch.softmax(-1) * self.bins).sum(-1) * 4 - 180) * (np.pi / 180)
        return yaw, pitch


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--format', choices=['mlmodel', 'mlpackage'], default='mlmodel')
    args = parser.parse_args()
    torch.set_num_threads(2)
    torch.manual_seed(42)
    weights = ROOT / 'weights/mobileone_s0.pt'
    backbone = mobileone_s0(pretrained=False, num_classes=90, inference_mode=True)
    backbone.load_state_dict(torch.load(weights, map_location='cpu', weights_only=True), strict=True)
    model = Gaze(backbone.eval()).eval()
    example = torch.rand(1, 3, 448, 448) * 255
    traced = torch.jit.trace(model, example)
    legacy = args.format == 'mlmodel'
    converted = ct.convert(
        traced,
        inputs=[ct.ImageType(name='face', shape=example.shape, color_layout=ct.colorlayout.RGB)],
        outputs=[ct.TensorType(name='yaw'), ct.TensorType(name='pitch')],
        convert_to='neuralnetwork' if legacy else 'mlprogram',
        minimum_deployment_target=ct.target.macOS11 if legacy else ct.target.macOS13,
        **({} if legacy else {'compute_precision': ct.precision.FLOAT32}),
    )
    converted.author = 'Yakhyokhuja Valikhujaev; Core ML conversion for ComfyPrompter'
    converted.license = 'MIT (see vendor/LICENSE)'
    converted.short_description = 'MobileOne S0 Gaze360: cropped RGB face to yaw/pitch in radians.'
    converted.input_description['face'] = '448x448 RGB face crop, pixels 0..255; normalization is included.'
    for name in ['yaw', 'pitch']:
        converted.output_description[name] = f'{name.capitalize()} in radians, shape [1].'
    converted.user_defined_metadata['source'] = 'https://github.com/yakhyo/gaze-estimation'
    converted.user_defined_metadata['source_commit'] = '4125329cfb0dd0071bb91e4c6ca994013db5a26b'
    output = ROOT / f'output/MobileOneS0Gaze.{args.format}'
    output.parent.mkdir(exist_ok=True)
    converted.save(str(output))
    # Validate the saved artifact through the actual Core ML runtime.
    runtime = ct.models.MLModel(str(output), compute_units=ct.ComputeUnit.CPU_ONLY)
    errors = []
    rng = np.random.default_rng(42)
    for pixels in [np.zeros((448,448,3), dtype=np.uint8),
                   np.full((448,448,3),127,dtype=np.uint8),
                   rng.integers(0,256,(448,448,3),dtype=np.uint8)]:
        tensor = torch.from_numpy(pixels.copy()).permute(2,0,1).unsqueeze(0).float()
        with torch.no_grad():
            expected = model(tensor)
        result = runtime.predict({'face': Image.fromarray(pixels)})
        for name, reference in zip(['yaw', 'pitch'], expected):
            error = float(np.max(np.abs(np.asarray(result[name]) - reference.numpy())))
            if not np.isfinite(error) or error > 0.02:
                raise RuntimeError(f'{name} parity failed: {error} radians')
            errors.append(error)
    report = {'artifact': output.name, 'checkpoint_sha256': hashlib.sha256(weights.read_bytes()).hexdigest(),
              'torch': torch.__version__, 'coremltools': ct.__version__, 'samples': 3,
              'max_absolute_error_radians': max(errors), 'tolerance_radians': 0.02,
              'validation': 'Saved Core ML artifact, CPU runtime vs PyTorch; synthetic images, not accuracy evaluation'}
    output.with_name(output.name + '.validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
