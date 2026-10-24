// Hourglass modeled by assembling 4 different phases: metal (0), glass (1), sand (2) and wood (3)

#include "common/render.glsl"

// Proxy offset
const float offset = 0.2;

// Wooden discs
// p : Point
float Wood(vec3 p) {
  vec3 pz = vec3(p.xy, abs(p.z));
  return D(Round(Cylinder(pz, vec3(0., 0., 6.1), vec3(0., 0.0, 6.7), 5.3), 0.1), Cylinder(pz, vec3(0., 0., 5.8), vec3(0., 0.0, 7.0), 2.2));
}

// Twisted metal rods
// p : Point
float Metal(vec3 p) {
  vec3 q = vec3(abs(p.xy), p.z);
  q -= vec3(3., 3., 0.);

  // Proxy: test against a capsule of radius 1.2, return the distance to a capsule of radius 1.0
  float b = Capsule(q, vec3(0.0, 0.0, -8.0), vec3(0.0, 0.0, 8.0), 1.0 + offset);
  if(b > 0.0)
    return b + offset;

  // Twist, the Lipschitz constant of the twisted box is bounded by 1.5
  float angle = q.z;
  vec3 qr = q;
  qr.xy = qr.xy * mat2(cos(angle), sin(angle), -sin(angle), cos(angle));
  float c = Box(qr, vec3(0.0, 0.0, 0.0), vec3(0.35, .35, 5.9)) / 1.5;

  vec3 qq = vec3(q.xy, abs(q.z));
  c = U(c, Cylinder(qq, vec3(0.0, 0.0, 5.8), vec3(0.0, 0.0, 6.0), 0.6));
  c = U(c, Cylinder(qq, vec3(0.0, 0.0, 5.9), vec3(0.0, 0.0, 7.1), 0.4));
  c = U(c, Cylinder(qq, vec3(0.0, 0.0, 6.8), vec3(0.0, 0.0, 7.0), 0.6));
  c = SU(c, Sphere(qq, vec3(0.0, 0.0, 7.7), 0.5), 0.1);

  return c;
}

// Glass bulbs filled with sand
// p : Point
vec4 Glass(vec3 p) {
  float gu = Sphere(p, vec3(0.0, 0.0, 3.5), 3.1);
  float gl = Sphere(p, vec3(0.0, 0.0, -3.5), 3.1);

  // Proxy: test against spheres of radius 3.9, return the distance to spheres of radius 3.7
  // The glass and the sand are within 3.64 of the sphere centers (radius 3.1 plus at most 0.54 from smooth union)
  float b = Round(U(gu, gl), 1.0) + offset;
  if(b > 0.0)
    return vec4(E, b + offset, b + offset, E);

  // Thin glass shell
  float g = SU(gl, gu, 0.54);
  float gg = SU(Sphere(p, vec3(0.0, 0.0, -3.5), 3.0), Sphere(p, vec3(0.0, 0.0, 3.5), 3.0), 0.51);
  g = SD(g, gg, 0.0005);

  // Sand
  float s = I(Box(p, vec3(0.0, 0.0, 1.25), vec3(4.0, 4.0, 1.25)), gg);
  float t = I(Round(Cone(p - vec3(0.0, 0.0, -3.0), vec2(sin(Pi / 3.5), cos(Pi / 3.5)), 3.5), 0.2), gg);
  s = U(s, t);

  return Under(Set(g, 1), Set(s, 2));
}

// Multiphase signed distance field of the model
// p : Point
vec4 Object(vec3 p) {
  p.z -= 5.;
  vec4 glass = Glass(p);
  vec4 metal = Set(Metal(p), 0);
  vec4 wood = Set(Wood(p), 3);

  vec4 v = Over(glass, wood);
  v = Under(metal, v);

  // Cut out a quarter
  v = Difference(v, Box(p, vec3(-5.0, -5.0, 0.0), vec3(5.0, 5.0, 11.0)));
  const float a = Pi / 4.0;
  p.xy = p.xy * mat2(cos(a), sin(a), -sin(a), cos(a));
  v = Difference(v, Box(p, vec3(-5.0, -5.0, 0.0), vec3(5.0, 5.0, 11.0)));

  return v;
}

// Image
void mainImage(out vec4 color, in vec2 pxy) {
  vec3 rgb = Render(pxy, iResolution.xy, iMouse.xy, vec3(24., 0., 7.), vec3(0., 0., 5.));
  color = vec4(rgb, 1.);
}
