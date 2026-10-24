// Animated contact surface between two phases

#define STEPS 500
#include "common/render.glsl"

// Multiphase signed distance field of the model
// p : Point
vec4 Object(vec3 p) {
  float a = SU(Sphere(p, vec3(-2.0, 0.0, 0.0), 3.0), Sphere(p, vec3(0.0, 0.0, 3.0), 2.0), 0.5);
  float b = Sphere(p, vec3(2.0, 0.0, 0.0), 3.0);

  // Animated contact coefficient
  float r = (sin(iTime) + 1.0) * 0.5;

  vec4 v = Contact(a, b, 1, 2, r);

  // Cut out half of the model to show the contact surface
  v = Difference(v, Box(p, vec3(0.0, -8.0, 0.0), vec3(7.0)));

  return v;
}

// Image
void mainImage(out vec4 color, in vec2 pxy) {
  vec3 rgb = Render(pxy, iResolution.xy, iMouse.xy, vec3(24., 0., 5.), vec3(0., 0., 0.));
  color = vec4(rgb, 1.);
}
