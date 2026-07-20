#include <flutter/runtime_effect.glsl>

uniform vec2 uCanvasSize;
uniform vec2 uImageSize;
uniform float uSmooth;
uniform float uBright;
uniform float uSlim;
uniform sampler2D uTexture;

out vec4 fragColor;

vec2 coverUv(vec2 canvasUv) {
  float canvasAspect = uCanvasSize.x / uCanvasSize.y;
  float imageAspect = uImageSize.x / uImageSize.y;
  vec2 uv = canvasUv;
  if (imageAspect > canvasAspect) {
    float visible = canvasAspect / imageAspect;
    uv.x = (uv.x - 0.5) * visible + 0.5;
  } else {
    float visible = imageAspect / canvasAspect;
    uv.y = (uv.y - 0.5) * visible + 0.5;
  }
  return uv;
}

void main() {
  vec2 canvasUv = FlutterFragCoord().xy / uCanvasSize;

  float yEnvelope = exp(-pow((canvasUv.y - 0.58) / 0.23, 2.0));
  float centerDistance = abs(canvasUv.x - 0.5) / 0.33;
  float xEnvelope = pow(max(0.0, 1.0 - centerDistance), 2.0);
  canvasUv.x = 0.5 + (canvasUv.x - 0.5) *
      (1.0 + uSlim * 0.065 * yEnvelope * xEnvelope);

  vec2 uv = coverUv(canvasUv);
  vec2 pixel = 1.0 / uImageSize;
  vec4 original = texture(uTexture, clamp(uv, 0.0, 1.0));

  vec4 softened = original * 0.28;
  softened += texture(uTexture, clamp(uv + vec2(pixel.x, 0.0), 0.0, 1.0)) * 0.12;
  softened += texture(uTexture, clamp(uv - vec2(pixel.x, 0.0), 0.0, 1.0)) * 0.12;
  softened += texture(uTexture, clamp(uv + vec2(0.0, pixel.y), 0.0, 1.0)) * 0.12;
  softened += texture(uTexture, clamp(uv - vec2(0.0, pixel.y), 0.0, 1.0)) * 0.12;
  softened += texture(uTexture, clamp(uv + pixel * 1.5, 0.0, 1.0)) * 0.06;
  softened += texture(uTexture, clamp(uv - pixel * 1.5, 0.0, 1.0)) * 0.06;
  softened += texture(uTexture, clamp(uv + vec2(pixel.x, -pixel.y) * 1.5, 0.0, 1.0)) * 0.06;
  softened += texture(uTexture, clamp(uv + vec2(-pixel.x, pixel.y) * 1.5, 0.0, 1.0)) * 0.06;

  float maxChannel = max(original.r, max(original.g, original.b));
  float minChannel = min(original.r, min(original.g, original.b));
  float skin = step(0.29, original.r) * step(0.12, original.g) *
      step(0.07, original.b) * step(original.g, original.r) *
      step(original.b, original.r) * step(0.045, maxChannel - minChannel);
  float smoothAmount = skin * uSmooth * 0.52;
  vec3 color = mix(original.rgb, softened.rgb, smoothAmount);

  float luminance = dot(color, vec3(0.299, 0.587, 0.114));
  color = mix(vec3(luminance), color, 1.0 + uBright * 0.08);
  color = (color - 0.5) * (1.0 + uBright * 0.055) + 0.5;
  color *= 1.0 + uBright * 0.055;
  color.r += skin * uBright * 0.012;

  fragColor = vec4(clamp(color, 0.0, 1.0), original.a);
}
