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
