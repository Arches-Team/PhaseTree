// Multiphase Sphere Tracing and shading
// The model must define the function vec4 Object(vec3 p)
// The number of steps and the marching epsilon can be changed by defining STEPS and EPSILON before including this file

// The body is skipped when the code is compiled as GLSL ES 1.00, i.e., when the VS Code shader-toy extension test compiles this file on its own
#if !defined(RENDER_GLSL) && __VERSION__ >= 300
#define RENDER_GLSL

#include "multiphase.glsl"

#ifndef STEPS
#define STEPS 200
#endif

#ifndef EPSILON
#define EPSILON 0.001
#endif

const int Steps = STEPS; // Maximum number of steps
const float Epsilon = EPSILON; // Marching epsilon

const float Pi = 3.14159265;

// Multiphase signed distance field of the model
// p : Point
vec4 Object(vec3 p);

struct Ray {
  vec3 o;
  vec3 d;
};

// Compute the point along the ray
// ray : The ray
//   t : Position
vec3 Eval(Ray ray, float t) {
  return ray.o + ray.d * t;
}

// Rotation matrix around z axis
// a : Angle
mat3 RotateZ(float a) {
  float sa = sin(a);
  float ca = cos(a);
  return mat3(ca, sa, 0., -sa, ca, 0., 0., 0., 1.);
}

// Compute the ray
//      m : Mouse position
//      p : Pixel
// ro, ta : Origin and target points
Ray CreateRay(vec2 m, vec2 p, vec3 ro, vec3 ta) {
  const float le = 3.8; // Focal length

  ro *= RotateZ(3. * Pi * m.x);
  ro *= 2.0 - clamp(m.y, 0.0, 1.0); // Zoom

  vec3 ww = normalize(ta - ro);
  vec3 uu = normalize(cross(ww, vec3(0., 0., 1.)));
  vec3 vv = normalize(cross(uu, ww));
  vec3 rd = normalize(p.x * uu + p.y * vv + le * ww);
  return Ray(ro, rd);
}

// Calculate object normal using the tetrahedron technique
// p : Point
// m : Index of the phase at point
vec3 ObjectNormal(vec3 p, int m) {
  const float eps = .001;
  const vec2 k = vec2(1.0, -1.0);
  return normalize(k.xyy * GetIth(Object(p + k.xyy * eps), m) +
    k.yyx * GetIth(Object(p + k.yyx * eps), m) +
    k.yxy * GetIth(Object(p + k.yxy * eps), m) +
    k.xxx * GetIth(Object(p + k.xxx * eps), m));
}

// Trace ray using Sphere Tracing on the union of all phases
// ray : The ray
//  rB : Maximum distance along the ray
//   t : Distance along the ray at the hit point
//   s : Number of steps
bool SphereTrace(Ray ray, float rB, out float t, out int s) {
  t = 0.0;

  for(int i = 0; i < Steps; i++) {
    s = i;
    vec3 p = Eval(ray, t);
    float v = MinPhase(Object(p));
    // Hit object
    if(v < 0.0) {
      return true;
    }
    // Move along ray
    t += max(Epsilon, abs(v));
    // Escape marched far away
    if(t > rB) {
      return false;
    }
  }
  return false;
}

// Lighting with shadows
// p : Point
// n : Unit normal
float Light(vec3 p, vec3 n) {
  // Point light
  const vec3 lp = vec3(-10., -15., 25.);

  vec3 d = normalize(lp - p);

  // Not even Phong shading, use weighted cosine instead for smooth transitions
  float diff = pow(.5 * (1. + dot(n, d)), 2.);

  int s;
  float t;
  bool h = SphereTrace(Ray(p + .1 * n, d), 25., t, s);
  if(!h) {
    return diff;
  }
  return 0.;
}

// Compute the color
// Could use a simpler version, the loop and safeguards are for debugging purposes
// v : Multiphase value at point
vec3 Color(vec4 v) {
  // Phase colors: 0 red, 1 green, 2 yellow, 3 blue
  const vec3 color[4] = vec3[4](vec3(1.0, 0.0, 0.0), vec3(0.0, 0.8, 0.2), vec3(0.9, 0.8, 0.1), vec3(0.0, 0.3, 0.9));

  int n = 0;
  vec3 c = vec3(0.0);
  for(int i = 0; i < 4; i++) {
    if(v[i] < 0.001) {
      c += color[i];
      n++;
    }
  }
  if(n == 0)
    return vec3(1.0, 1.0, 1.0);
  c /= float(n);
  return c;
}

// Shading and lighting
// p : Point
// n : Normal at point
// v : Multiphase value at point
vec3 Shade(vec3 p, vec3 n, vec4 v) {
  return 0.35 + 0.5 * Color(v) + 0.15 * Light(p, n);
}

// Shading with false colors representing the number of steps
// n : Number of steps
vec3 ShadeSteps(int n) {
  float t = float(n) / (float(Steps - 1));
  return .5 + mix(vec3(.05, .05, .5), vec3(.65, .39, .65), t);
}

// Picture in picture
//      pixel : Pixel
// resolution : Image resolution
//        pip : Picture in picture enabled on input, true if pixel was in sub-picture zone on output
vec2 Pip(vec2 pixel, vec2 resolution, inout bool pip) {
  // Pixel coordinates
  vec2 p = (-resolution + 2. * pixel) / resolution.y;
  if(pip == true) {
    const float fraction = 1. / 4.;
    // Recompute pixel coordinates in sub-picture
    if((pixel.x < resolution.x * fraction) && (pixel.y < resolution.y * fraction)) {
      p = (-resolution * fraction + 2. * pixel) / (resolution.y * fraction);
      pip = true;
    } else {
      pip = false;
    }
  }
  return p;
}

// Render the model, the sub-picture in the lower left corner shows the number of steps
//      pxy : Pixel
// resolution : Image resolution
//    mouse : Mouse position
//   ro, ta : Camera origin and target points
vec3 Render(vec2 pxy, vec2 resolution, vec2 mouse, vec3 ro, vec3 ta) {
  // Picture in picture on
  bool pip = true;

  // Pixel
  vec2 pixel = Pip(pxy, resolution, pip);

  // Mouse
  vec2 m = mouse / resolution;

  // Camera
  Ray ray = CreateRay(m, pixel, ro, ta);

  // Trace ray
  float t;
  int s;
  bool h = SphereTrace(ray, 100., t, s);

  // Background
  vec3 rgb = vec3(0.595, 0.585, 0.995);

  if(h) {
    vec3 p = Eval(ray, t);

    // Evaluate the object once, the phase at point gives the normal and the color
    vec4 v = Object(p);

    // Compute normal
    vec3 n = ObjectNormal(p, MinIndex(v));

    // Shade object with light
    rgb = Shade(p, n, v);
  }

  // Shade the sub-picture with false colors representing the number of steps
  if(pip == true) {
    rgb = ShadeSteps(s);
  }

  return rgb;
}

#endif
