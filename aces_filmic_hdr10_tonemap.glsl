#version 330 core
// ACES Filmic Tonemapping for HDR10 PQ → ACEScg → sRGB (Rec.709)
//
// Save as "aces_filmic_hdr10_tonemap.glsl"
// Load in mpv: --glsl-shader=/path/to/aces_filmic_hdr10_tonemap.glsl
//
// Author: ChatGPT (OpenAI), 2025
// Based on ACES RRT+ODT fit (K. Narkowicz)

uniform sampler2D texture;
in vec2 texcoord;
out vec4 out_color;

// ---- User-tunable controls ----
uniform float exposure = 0.0;      // Exposure compensation in stops
uniform float saturation = 1.0;    // Color saturation
uniform float strength = 1.0;      // Mix between linear & tonemapped
uniform float shoulder = 1.0;      // Highlight rolloff tweak

// ---- PQ (ST2084) constants ----
const float PQ_m1 = 2610.0 / 16384.0;
const float PQ_m2 = 2523.0 / 32.0;
const float PQ_c1 = 3424.0 / 4096.0;
const float PQ_c2 = 2413.0 / 128.0;
const float PQ_c3 = 2392.0 / 128.0;

// ---- EOTF: Convert PQ → Linear (cd/m² normalized to 0–1 range for ACES pipeline) ----
float pq_to_linear(float x) {
    float Y = pow(max(x, 0.0), 1.0 / PQ_m2);
    float num = max(Y - PQ_c1, 0.0);
    float den = PQ_c2 - PQ_c3 * Y;
    return pow(num / den, 1.0 / PQ_m1);
}

vec3 pq_to_linear(vec3 x) {
    return vec3(pq_to_linear(x.r), pq_to_linear(x.g), pq_to_linear(x.b));
}

// ---- Color space conversion matrices ----
// Rec.2020 → ACEScg (AP1)
const mat3 REC2020_TO_AP1 = mat3(
     1.6410233797, -0.3248032942, -0.2364246952,
    -0.6636628587,  1.6153315917,  0.0167563477,
     0.0117218943, -0.0082844420,  0.9883948585
);

// ACEScg (AP1) → sRGB (Rec.709)
const mat3 AP1_TO_SRGB = mat3(
     1.705051, -0.621792, -0.083259,
    -0.130257,  1.140803, -0.010548,
    -0.024003, -0.128968,  1.152971
);

// ---- ACES Filmic Tonemap fit ----
vec3 RRTAndODTFit(vec3 v) {
    vec3 a = v * (v + 0.0245786) - 0.000090537;
    vec3 b = v * (v * 0.983729 + 0.4329510) + 0.238081;
    return a / b;
}

vec3 aces_filmic(vec3 color) {
    color = RRTAndODTFit(color);
    return clamp(color, 0.0, 1.0);
}

// ---- sRGB OETF ----
vec3 linear_to_srgb(vec3 c) {
    vec3 low  = c * 12.92;
    vec3 high = 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055;
    vec3 cond = step(vec3(0.0031308), c);
    return mix(low, high, cond);
}

// ---- Utility: adjust saturation ----
vec3 adjust_saturation(vec3 color, float sat) {
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    return mix(vec3(luma), color, sat);
}

void main() {
    vec3 hdr_pq = texture(texture, texcoord).rgb;

    // Convert PQ to scene-linear luminance (normalized)
    vec3 hdr_linear = pq_to_linear(hdr_pq);

    // Map Rec.2020 → ACEScg
    vec3 aces = REC2020_TO_AP1 * hdr_linear;

    // Apply exposure
    aces *= pow(2.0, exposure);

    // Apply ACES filmic curve
    vec3 tone = aces_filmic(aces * shoulder);

    // Blend between linear and tonemapped
    vec3 blended = mix(aces / (aces + vec3(1.0)), tone, strength);

    // Adjust saturation
    blended = adjust_saturation(blended, saturation);

    // Convert ACEScg → sRGB display space
    vec3 srgb = AP1_TO_SRGB * blended;

    // Convert linear → sRGB
    srgb = linear_to_srgb(srgb);

    out_color = vec4(clamp(srgb, 0.0, 1.0), 1.0);
}
