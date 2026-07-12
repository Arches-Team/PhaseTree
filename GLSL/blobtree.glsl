// BlobTree model
// The functions have been changed to return both the potential field and the distance to the compact support
const float T = 0.5;

// Smooth cubic falloff function
// x : distance
// R : Radius
float Falloff(float x, float R) {
  float u = clamp(x / R, 0.0, 1.0);
  float v = (1.0 - u * u);
  return v * v * v;
}

// Primitives

// Point skeleton
// p : Point
// c : Center of skeleton
// e : Energy associated to skeleton
// R : Radius
vec2 Point(vec3 p, vec3 c, float e, float R) {
  return vec2(e * Falloff(length(p - c), R), length(p - c) - R);
}

// Operators

// Blending
// a,b : field function of the sub-trees
vec2 Blend(vec2 a, vec2 b) {
  return vec2(a.x + b.x, min(a.y, b.y));
}

// Potential field of the object
// p : point
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

// Convert BlobTree field function to signed distance field
// v : Vector storing the value of the field, and the distance to the compact support
// k : Lipschitz constant of the BlobTree
float BlobToSdf(vec2 v, float k) {
  if(v.y < 0.0) {
    return -v.x / k;
  }

  return T / k + v.y;
}

// ----------------------------------------------------------------- END BLOBTREE

struct Ray {
  vec3 o;
  vec3 d;
};

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
// m : Mouse position
// p : Pixel
// or, ta : Origin and target points
Ray CreateRay(vec2 m, vec2 p, vec3 or, vec3 ta) {
  float a = 3. * 3.1415 * m.x;
  float le = 3.8;

  or *= RotateZ(3. * 3.14 * m.x);
  or *= 2.0 - clamp(m.y, 0.0, 1.0); // Zoom

  vec3 ww = normalize(ta - or);
  vec3 uu = normalize(cross(ww, vec3(0., 0., 1.)));
  vec3 vv = normalize(cross(uu, ww));
  vec3 rd = normalize(p.x * uu + p.y * vv + le * ww);
  return Ray(or, rd);
}

const int Steps = 400;
const float Epsilon = .005;// Marching epsilon

// Primitives ------------------------------------------------------------------------------------

const float E = 1e4;

int Int(float x) {
  return (x > 0.0) ? int(x) : int(x) - 1;
}

// --------------------------------------------------- START MULTI PHASE ONDULE

// Slicer infinite primitive
//    p : Point
// a, b : Phases
//    u : Normal direction of the slabs
//    e : Thickness
vec4 Slicer(vec3 p, int a, int b, vec3 uz, float e) {
  float z = dot(uz, p);

  vec3 ux = normalize(vec3(-uz.y, uz.x, 0.0));
  vec3 uy = cross(ux, uz);

  float x = dot(ux, p);
  float y = dot(uy, p);
  // We will not take into account the Lipschitz factor of the warping here
  p -= 0.5 * e * sin(x / (0.5 * e)) * uz;

  float d = dot(uz, p);

  int k = (Int(d / e)) % 2;
  d = fract(d / e) * e;
  d = min(d, e - d);

  float v[4] = float[](E, E, E, E); // Initialize array to infinity
  if(k == 0)
    d = -d;
  v[a] = d;
  v[b] = -d;
  return vec4(v[0], v[1], v[2], v[3]);
}

// Operators ----------------------------------------------------------------------------------

vec4 Inter(vec4 a, float b) {
  return vec4(max(a.x, b), max(a.y, b), max(a.z, b), max(a.w, b));
}

vec4 Extract(vec4 a, int m) {
  float aa[4] = float[4](a.x, a.y, a.z, a.w);
  float cc[4] = float[4](E, E, E, E);

  cc[m] = aa[m];
  return vec4(cc[0], cc[1], cc[2], cc[3]);
}
vec4 ToPhase(float x, int m) {
  float c[4] = float[4](E, E, E, E);

  c[m] = x;
  return vec4(c[0], c[1], c[2], c[3]);
}

vec4 Keep(vec4 v, int m) {
  float cc[4] = float[4](E, E, E, E);
  cc[m] = v[m];
  return vec4(cc[0], cc[1], cc[2], cc[3]);
}

vec4 Shrink(vec4 v) {
  return v + 0.05;
}

// ------------------------------------------------------------------------------ START OBJECT
// Potential field of the object
// p : point
vec4 Object(vec3 p) {

  // 1 vert 2 jaune 3 bleu 0 rouge
  float b = BlobToSdf(Blob(p), 2.0);
  vec4 v = ToPhase(b, 1);

  vec4 w = Slicer(p, 1, 2, normalize(vec3(1, 2, 1)), 1.0);

  w = Inter(w, b); // Coupe générale
  v = Shrink(w);

  return v;
}

// Get minimum phase
float MinPhase(vec4 x) {
  return min(min(x.x, x.y), min(x.z, x.w));
}

// Get index of the minimum phase
int MinIndex(vec4 v) {
  return (v.y < v.x) ? ((v.z < v.y) ? ((v.w < v.z) ? 3 : 2) : ((v.w < v.y) ? 3 : 1)) : ((v.z < v.x) ? ((v.w < v.z) ? 3 : 2) : ((v.w < v.x) ? 3 : 0));
}

// Get i-th element of multiphase, obvious, provided here only in case of array implementation
float GetIth(vec4 a, int i) {
  return a[i];
}

// Calculate object normal
// p : point
vec3 ObjectNormal(vec3 p) {
  const float eps = .001;
  vec3 n;
  vec4 ov = Object(p);
  int mi = MinIndex(ov);
  float v = GetIth(ov, mi);
  n.x = GetIth(Object(vec3(p.x + eps, p.y, p.z)), mi) - v;
  n.y = GetIth(Object(vec3(p.x, p.y + eps, p.z)), mi) - v;
  n.z = GetIth(Object(vec3(p.x, p.y, p.z + eps)), mi) - v;
  return normalize(n);
}

// Trace ray using ray marching
// ray : the ray 
// h : hit
// s : Number of steps
bool SphereTrace(Ray ray, float rB, out float t, out int s) {
  t = 0.0;

  for(int i = 0; i < Steps; i++) {
    s = i;
    vec3 p = Eval(ray, t);
    float v = MinPhase(Object(p));
    // Hit object
    if(v < 0.0) {
      s = i;
      return true;
    }
    // Move along ray
    t += max(Epsilon, abs(v) / 1.);
    // Escape marched far away
    if(t > rB) {
      return false;
    }
  }
  return false;
}

// Lighting with shadows
// p : Point.
// n : Unit normal.
float Light(vec3 p, vec3 n) {
  const vec3 lp = vec3(-10., -15., 25.);
  // point light

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
// Could use a simpler version, the loop and safeguards are for debuging purposes
// p : Point.
vec3 Color(vec3 p) {
  // Array of colors
  const vec3 color[4] = vec3[4](vec3(1.0, 0.0, 0.0), vec3(0.0, 0.8, 0.2), vec3(0.9, 0.8, 0.1), vec3(0.0, 0.3, 0.9));
  vec4 v = Object(p);

  int n = 0;
  vec3 c = vec3(0.0);
  for(int i = 0; i < 4; i++) {
    if(v[i] < 0.001) {
      c += color[i];
      n++;
    }
  }
  if(n == 0)
    return vec3(1., 1.0, 1.0);
  c /= float(n);
  return c;
}

// Shading and lighting
// p : point.
// n : Normal at point.
vec3 Shade(vec3 p, vec3 n) {
  vec3 c = 0.35 + 0.5 * Color(p) + 0.15 * Light(p, n);
  return c;
}

// Shading with number of steps
vec3 ShadeSteps(int n) {
  float t = float(n) / (float(Steps - 1));
  return .5 + mix(vec3(.05, .05, .5), vec3(.65, .39, .65), t);
}

// Picture in picture
// pixel : Pixel
// pip : Boolean, true if pixel was in sub-picture zone
vec2 Pip(vec2 pixel, out bool pip) {
  // Pixel coordinates
  vec2 p = (-iResolution.xy + 2. * pixel) / iResolution.y;
  if(pip == true) {
    const float fraction = 1. / 4.;
    // Recompute pixel coordinates in sub-picture
    if((pixel.x < iResolution.x * fraction) && (pixel.y < iResolution.y * fraction)) {
      p = (-iResolution.xy * fraction + 2. * pixel) / (iResolution.y * fraction);
      pip = true;
    } else {
      pip = false;
    }
  }
  return p;
}

// Image
void mainImage(out vec4 color, vec2 pxy) {
  // Picture in picture on
  bool pip = true;

  // Pixel
  vec2 pixel = Pip(pxy, pip);

  // Mouse
  vec2 m = iMouse.xy / iResolution.xy;

  // Camera
  Ray ray = CreateRay(m, pixel, vec3(24., 0., 7.), vec3(0., 0., 0.));

  // Trace ray

  // Hit and number of steps
  float t;
  int s;

  bool h = SphereTrace(ray, 100., t, s);

  // Position
  vec3 pt = Eval(ray, t);

  // Shade background
  vec3 rgb = vec3(0.595, 0.585, 0.995);

  if(h) {
    // Compute normal
    vec3 n = ObjectNormal(pt);

    // Shade object with light
    rgb = Shade(pt, n);
  }

  // Uncomment this line to shade image with false colors representing the number of steps
  if(pip == true) {
    rgb = ShadeSteps(s);
  }

  color = vec4(rgb, 1.);
}
