// Minimal model: a sphere with a single phase
// Provides a fast rendering setup to start from when writing other models

#define STEPS 500
#include "common/render.glsl"

// Multiphase signed distance field of the model
// p : Point
vec4 Object(vec3 p) {
  return Set(Sphere(p, vec3(0.0), 3.0), 1);
}

// Image
void mainImage(out vec4 color, in vec2 pxy) {
  vec3 rgb = Render(pxy, iResolution.xy, iMouse.xy, vec3(24., 0., 5.), vec3(0., 0., 0.));
  color = vec4(rgb, 1.);
}
