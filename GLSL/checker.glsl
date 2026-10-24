// Infinite random multiphase checker intersected with a blobby shape

#include "common/render.glsl"

// Multiphase signed distance field of the model
// p : Point
vec4 Object(vec3 p) {
  p.z = -p.z;

  // Blobby shape
  float b = SU(Sphere(p, vec3(-4., -1., -1.), 3.0), Sphere(p, vec3(2., 2., 2.), 4.0), 1.0);

  // Use either checker infinite primitive
  // vec4 v = Checker(p, 1, 2);
  vec4 v = Checker(p, 4);
  v = Intersection(v, b);

  // Remove two phases just to see the consistent remaining two-phase fields
  v = Remove(v, 2);
  v = Remove(v, 1);

  return v;
}

// Image
void mainImage(out vec4 color, in vec2 pxy) {
  vec3 rgb = Render(pxy, iResolution.xy, iMouse.xy, vec3(24., 0., 7.), vec3(0., 0., 0.));
  color = vec4(rgb, 1.);
}
