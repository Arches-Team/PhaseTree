// BlobTree model converted to a signed distance field and sliced with wavy two-phase slabs

#define STEPS 400
#define EPSILON 0.005
#include "common/render.glsl"
#include "common/blobtree.glsl"

// BlobTree field function of the blob
// p : Point
vec2 Blob(vec3 p) {
  vec2 v = Blend(Point(p, vec3(0.0, 1.0, 1.0), 1.0, 4.5), Point(p, vec3(2.0, 0.0, -3.0), 1.0, 4.5));

  v = Blend(v, Point(p, vec3(-3.0, 2.0, -3.0), 1.0, 4.5));
  v = Blend(v, Point(p, vec3(-1.0, -3.0, 0.0), 1.0, 4.0));
  v = Blend(v, Point(p, vec3(3.0, 4.0, 2.0), 1.0, 4.0));
  v = Blend(v, Point(p, vec3(2.0, -2.0, 4.0), 1.0, 4.0));
  v = Blend(v, Point(p, vec3(-2.0, 2.0, 5.0), 1.0, 4.0));
  v.x -= T;
  return v;
}

// Multiphase signed distance field of the model
// p : Point
vec4 Object(vec3 p) {
  float b = BlobToSdf(Blob(p), 2.0);

  vec4 v = Slicer(p, 1, 2, normalize(vec3(1, 2, 1)), 1.0);

  // Restrict the slabs to the blob
  v = Intersection(v, b);
  v = Shrink(v, 0.05);

  return v;
}

// Image
void mainImage(out vec4 color, in vec2 pxy) {
  vec3 rgb = Render(pxy, iResolution.xy, iMouse.xy, vec3(24., 0., 7.), vec3(0., 0., 0.));
  color = vec4(rgb, 1.);
}
