# ComfyPrompter

macOS teleprompter with camera-based gaze estimation.

## SnapCore dependency

If Xcode shows **SnapCore** as a local package, replace the local package reference
with the repository at [AryanRogye/SnapCore](https://github.com/AryanRogye/SnapCore).
In Xcode, remove the local SnapCore package reference, then choose **File → Add
Package Dependencies…**, enter `https://github.com/AryanRogye/SnapCore`, and add
its library product to the **ComfyPrompter** target.

## Gaze model setup

The app uses the pretrained MobileOne S0 Gaze360 model from
[yakhyo/gaze-estimation](https://github.com/yakhyo/gaze-estimation).
`ModelConversion/` is ignored by Git. The reproducible exporter, architecture,
dependencies, and upstream license live in `scripts/gaze-conversion/` so they can
be committed independently of the local environment, weights, and exports.

### Convert the model

Requires macOS, Python 3.12, and [uv](https://docs.astral.sh/uv/).
Run these commands from the project root:

```sh
mkdir -p ModelConversion/GazeEstimation/weights
cp -R scripts/gaze-conversion/. ModelConversion/GazeEstimation/
curl -fL https://github.com/yakhyo/gaze-estimation/releases/download/weights/mobileone_s0.pt \
  -o ModelConversion/GazeEstimation/weights/mobileone_s0.pt
echo 'f50c99087f85f9a4fc8d75bd394262b6fcbc4ae21112928f67fabbf840664c95  ModelConversion/GazeEstimation/weights/mobileone_s0.pt' | shasum -a 256 -c -

cd ModelConversion/GazeEstimation
uv venv --python 3.12 .venv
uv pip install --python .venv/bin/python -r requirements.txt
.venv/bin/python convert.py
.venv/bin/python convert.py --format mlpackage
```

Outputs are `output/MobileOneS0Gaze.mlmodel` and
`output/MobileOneS0Gaze.mlpackage`. Use either one in Xcode, not both with the
same name. Both retain FP32 precision. Each export runs the saved model through
the Core ML CPU runtime against PyTorch on three synthetic images and writes an
adjacent `*.validation.json` report. This checks conversion parity, not accuracy
on real faces. FP16 was tried but exceeded the numeric tolerance.

The vendored architecture is from upstream commit
`4125329cfb0dd0071bb91e4c6ca994013db5a26b`; attribution is preserved in
`scripts/gaze-conversion/vendor/LICENSE` and the source header.

### Add and load the model

The app currently uses `ComfyPrompter/Resources/MobileOneS0Gaze.mlpackage`.
For a fresh setup, copy the exported package to that location. In Xcode, ensure
the model belongs to the **ComfyPrompter** target and its Core ML Codegen setting
is **Class Definition**. Xcode compiles it and generates `MobileOneS0Gaze` and
`MobileOneS0GazeInput`. Keep the package's complete directory contents together.

The existing `GazeDetection.loadModel()` loads the compiled bundled model.
The underlying Core ML flow is:

```swift
import CoreML

let configuration = MLModelConfiguration()
configuration.computeUnits = .all
let model = try MLModel(
    contentsOf: MobileOneS0Gaze.urlOfModelInThisBundle,
    configuration: configuration
)

// facePixelBuffer: CVPixelBuffer containing a 448 × 448 face crop.
let input = MobileOneS0GazeInput(face: facePixelBuffer)
let result = try model.prediction(from: input)
guard
    let yaw = result.featureValue(for: "yaw")?.multiArrayValue?[0].doubleValue,
    let pitch = result.featureValue(for: "pitch")?.multiArrayValue?[0].doubleValue
else {
    throw GazeError.cantGetGazeInfo
}
```

`GazeDetection` is main-actor isolated: call `loadModel()` before `getGaze(from:boundingBox:)`.
The latter accepts a camera buffer and normalized Vision face bounding box,
uses `ImageHelpers` to produce a 448 × 448 BGRA buffer, and returns `GazeResult`.
For preprocessing that matches upstream inference, resize the face crop to fill
448 × 448; the current image helper instead preserves aspect ratio with padding.

The model image input is named `face`; use ordinary RGB pixels (a BGRA
`CVPixelBuffer` is supported by Core ML). Normalization and output decoding are
inside the graph. Do not normalize again. `yaw` and `pitch` are single-element
arrays in radians. The model needs a detected face crop; screen coordinates
require additional calibration.
