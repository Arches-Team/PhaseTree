struct Ray {
  vec3 o;
  vec3 d;
};

vec3 Eval(Ray ray, float t) {
  return ray.o + ray.d * t;
}

// Hashing function
// Returns a random number in [-1,1]
float Hash(float seed) {
  return fract(sin(seed) * 43758.5453);
}

// Cosine direction
vec3 Cosine(float seed, vec3 nor) {
  float u = Hash(78.233 + seed);
  float v = Hash(10.873 + seed);

  float a = 6.2831853 * v;
  u = 2. * u - 1.;
  return normalize(nor + vec3(sqrt(1. - u * u) * vec2(cos(a), sin(a)), u));
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

const int Steps = 200;      // Maximum number of steps
const float Epsilon = .001; // Marching epsilon

// Signed distance fields

const float E = 1e4;

// Sphere
float Sphere(vec3 p, vec3 c, float R) {
  float d = length(p - c) - R;
  return d;
}

// Box
// p : Point
// c : Center
// r : Radius, i.e. dimension of the box
float Box(vec3 p, vec3 c, vec3 r) {

  vec3 q = abs(p - c) - r;
  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float Slab(vec3 p, vec3 c, vec3 n, float r) {
  float d = abs(dot(p - c, normalize(n))) - r;
  return d;
}

float Capsule(vec3 p, vec3 a, vec3 b, float r) {
  vec3 pa = p - a, ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h) - r;
}

float Cone(vec3 p, vec2 c, float h) {
  // c is the sin/cos of the angle, h is height
  // Alternatively pass q instead of (c,h),
  // which is the point at the base in 2D
  vec2 q = h * vec2(c.x / c.y, -1.0);

  p = p.xzy;
  vec2 w = vec2(length(p.xz), p.y);
  vec2 a = w - q * clamp(dot(w, q) / dot(q, q), 0.0, 1.0);
  vec2 b = w - q * vec2(clamp(w.x / q.x, 0.0, 1.0), 1.0);
  float k = sign(q.y);
  float d = min(dot(a, a), dot(b, b));
  float s = max(k * (w.x * q.y - w.y * q.x), k * (w.y - q.y));
  return sqrt(d) * sign(s);
}

float Cylinder(vec3 p, vec3 a, vec3 b, float r) {
  vec3 ba = b - a;
  vec3 pa = p - a;
  float baba = dot(ba, ba);
  float paba = dot(pa, ba);
  float x = length(pa * baba - ba * paba) - r * baba;
  float y = abs(paba - baba * 0.5) - baba * 0.5;
  float x2 = x * x;
  float y2 = y * y * baba;
  float d = (max(x, y) < 0.0) ? -min(x2, y2) : (((x > 0.0) ? x2 : 0.0) + ((y > 0.0) ? y2 : 0.0));
  return sign(d) * sqrt(abs(d)) / baba;
}

float U(float a, float b) {
  return min(a, b);
}

float U(float a, float b, float c) {
  return min(a, min(b, c));
}
float SU(float a, float b, float r) {
  r *= 6.0;
  float h = max(r - abs(a - b), 0.0) / r;
  return U(a, b) - h * h * h * r * (1.0 / 6.0);
}

float D(float a, float b) {
  return max(a, -b);
}
float SD(float a, float b, float r) {
  r *= 6.0;
  float h = max(r - abs(-a - b), 0.0) / r;
  return max(a, -b);//- h*h*h*r*(1.0/6.0);
}

float I(float a, float b) {
  return max(a, b);
}

float Round(float a, float r) {
  return a - r;
}

// Multiphase operators
// Mostly binary operators that combine multiphase objects

vec4 Set(float a, int m) {
  vec4 pa = vec4(E);
  pa[m] = a;
  return pa;
}

// Under
// a : field function of left sub-tree
// b : field function of right sub-tree
vec4 Under(vec4 a, vec4 b) {
 // Same material
  return vec4(D(U(a.x, b.x), U(a.y, a.z, a.w)), D(U(a.y, b.y), U(a.x, a.z, a.w)), D(U(a.z, b.z), U(a.x, a.y, a.w)), D(U(a.w, b.w), U(a.x, a.y, a.z)));
}

// Over
// a,b : field functions of left and right sub-trees
vec4 Over(vec4 a, vec4 b) {
  return Under(b, a);
}

float MinMat(vec4 x) {
  return min(min(x.x, x.y), min(x.z, x.w));
}

int MinIndex(vec4 v) {
  return (v.y < v.x) ? ((v.z < v.y) ? ((v.w < v.z) ? 3 : 2) : ((v.w < v.y) ? 3 : 1)) : ((v.z < v.x) ? ((v.w < v.z) ? 3 : 2) : ((v.w < v.x) ? 3 : 0));
}

float GetIth(vec4 a, int i) {
  float aa[4] = float[4](a.x, a.y, a.z, a.w);
  return aa[i];
}

// Hybrid operators
// They combine a multiphase object with a simple sign distane field

vec4 Inter(vec4 a, float b) {
  return vec4(max(a.x, b), max(a.y, b), max(a.z, b), max(a.w, b));
}

vec4 Extract(vec4 a, int m) {
  float aa[4] = float[4](a.x, a.y, a.z, a.w);
  float cc[4] = float[4](E, E, E, E);

  cc[m] = aa[m];
  return vec4(cc[0], cc[1], cc[2], cc[3]);
}

vec4 Keep(vec4 v, int m) {
  float cc[4] = float[4](E, E, E, E);
  cc[m] = v[m];
  return vec4(cc[0], cc[1], cc[2], cc[3]);
}

vec4 Difference(vec4 a, float b) {
  return vec4(max(a.x, -b), max(a.y, -b), max(a.z, -b), max(a.w, -b));
}

// Objects

float Wood(vec3 p) {
  vec3 pz = vec3(p.xy, abs(p.z));
  float d = D(Round(Cylinder(pz, vec3(0., 0., 6.1), vec3(0., 0.0, 6.7), 5.3), 0.1), Cylinder(pz, vec3(0., 0., 5.8), vec3(0., 0.0, 7.0), 2.2));

  return d;
}

const float offset = 0.2;

float Metal(vec3 p) {
  vec3 q = vec3(abs(p.xy), p.z);
  q -= vec3(3., 3., 0.);

  // Optimize with proxies
  float b = Capsule(q, vec3(0.0, 0.0, -8.0), vec3(0.0, 0.0, 8.0), 1.0 + offset);
  if(b > 0.0)
    return b + offset;

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

vec4 Glass(vec3 p) {

  float gu = Sphere(p, vec3(0.0, 0.0, 3.5), 3.1);
  float gl = Sphere(p, vec3(0.0, 0.0, -3.5), 3.1);
// Proxy
  float b = Round(U(gu, gl), 1.0) + offset;
  if(b > 0.0)
    return vec4(E, b + offset, b + offset, E);

  float g = SU(gl, gu, 0.54);

  float gg = SU(Sphere(p, vec3(0.0, 0.0, -3.5), 3.0), Sphere(p, vec3(0.0, 0.0, 3.5), 3.0), 0.51);
  g = SD(g, gg, 0.0005);

 // Sable
  float s = I(Box(p, vec3(0.0, 0.0, 1.25), vec3(4.0, 4.0, 1.25)), gg);
  float t = I(Round(Cone(p - vec3(0.0, 0.0, -3.0), vec2(sin(3.14 / 3.5), cos(3.14 / 3.5)), 3.5), 0.2), gg);
  s = U(s, t);
  vec4 sand = Set(s, 2);

  vec4 v = Set(g, 1);
  v = Under(v, sand);
  return v;
}

// Potential field of the object
// p : point
vec4 Object(vec3 p) {

  p.z -= 5.;
  vec4 glass = Glass(p);
  vec4 metal = Set(Metal(p), 0);

// Wood
  vec4 Wood = Set(Wood(p), 3);
  vec4 v = Over(glass, Wood);
  v = Under(metal, v);
  v = Difference(v, Box(p, vec3(-5.0, -5.0, 0.0), vec3(5.0, 5.0, 11.0)));

  const float a = 3.1415 / 4.0;
  p.xy = p.xy * mat2(cos(a), sin(a), -sin(a), cos(a));
  v = Difference(v, Box(p, vec3(-5.0, -5.0, 0.0), vec3(5.0, 5.0, 11.0)));

  return v;
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
    float v = MinMat(Object(p));
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

// Ambient occlusion
// p : Point
// n : Normal
// a : Number of smaples
float AmbientOcclusion(vec3 p, vec3 n, float r, int a) {
  if(a == 0) {
    return 1.;
  }

  float ao = 0.;

  for(int i = 0; i < a; i++) {
    vec3 d = Cosine(581.123 * float(i), n);

    int s;
    float t;
    bool h = SphereTrace(Ray(p, d), r, t, s);
    if(!h) {
      ao += 1.;
    }
  }

  ao /= float(a);
  return ao;
}

// Background color
vec3 background(vec3 rd) {
  return mix(vec3(.652, .451, .995), vec3(.552, .897, .995), rd.z * .5 + .5);
}

const vec3 lp = vec3(5., 10., 25.);

float Light(vec3 p, vec3 n) {
  // point light

  vec3 l = normalize(lp - p);

  // Not even Phong shading, use weighted cosine instead for smooth transitions
  float diff = pow(.5 * (1. + dot(n, l)), 2.);

  int s;
  float t;
  bool h = SphereTrace(Ray(p + .1 * n, l), 25., t, s);
  if(!h) {
    return diff;
  }
  return 0.;
}

float SmoothLight(vec3 p, vec3 n, int a) {
  if(a == 0)
    return 1.;

  // point light  
  vec3 l = normalize(lp - p);

  float lo = 0.;

  for(int i = 0; i < a; i++) {
    vec3 d = Cosine(581.123 * float(i), n);
    d = normalize(l + d * .15);
    int s;
    float t;
    bool h = SphereTrace(Ray(p, d), 20., t, s);
    if(!h) {
      lo += 1.;
    } else if(t > 100.) {
      lo += 1.;
    }
  }

  lo /= float(a);
  return lo;

}

vec3 Color(vec3 p) {
  vec4 v = Object(p);
  vec3 c = vec3(0.0);
  int n = 0;
  if(v.x < 0.001) {
    c += vec3(1.0, 0.0, 0.0);
    n++;
  }
  if(v.y < 0.001) {
    c += vec3(0.0, 0.6, 0.0);
    n++;
  }
  if(v.z < 0.001) {
    c += vec3(0.9, 0.8, 0.0);
    n++;
  }
  if(v.w < 0.001) {
    c += vec3(0.0, 0.2, 1.0);
    n++;
  }
  if(n == 0)
    return vec3(1., 1.0, 1.0);
  c /= float(n);
  return c;
}

// Shading and lighting
// p : point,
// n : normal at point
vec3 Shade(vec3 p, vec3 n) {
  vec3 c = 0.1 + 0.15 * background(n) + 0.65 * Color(p);
  c += .2 * AmbientOcclusion(p + .025 * n, n, 20.0, 0) * vec3(1., 1., 1.);
  c += .2 * Light(p, n);
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
  Ray ray = CreateRay(m, pixel, vec3(24., 0., 7.), vec3(0., 0., 5.));

  // Trace ray

  // Hit and number of steps
  float t;
  int s;

  bool h = SphereTrace(ray, 100., t, s);

  // Position
  vec3 pt = Eval(ray, t);

  // Shade background
  vec3 rgb = background(ray.d);

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
