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

const int Steps = 500;
const float Epsilon = .001;// Marching epsilon

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

// Union
// a, b : Fields
float U(float a, float b) {
  return min(a, b);
}

// Ternary union
// a, b, c : Fields
float U(float a, float b, float c) {
  return min(a, min(b, c));
}
// Smooth union
// a, b : Fields
//    r : Radius
float SU(float a, float b, float r) {
  r *= 6.0;
  float h = max(r - abs(a - b), 0.0) / r;
  return U(a, b) - h * h * h * r * (1.0 / 6.0);
}

// Difference
// a, b : Fields
float D(float a, float b) {
  return max(a, -b);
}

// Intersection
// a, b : Fields
float I(float a, float b) {
  return max(a, b);
}

// Set Phase
// a : Field
// m : Phase index
vec4 Set(float a, int m) {
  vec4 pa = vec4(E);
  pa[m] = a;
  return pa;
}

vec4 Difference(vec4 a, float b) {
  return vec4(max(a.x, -b), max(a.y, -b), max(a.z, -b), max(a.w, -b));
}

vec4 Contact(float a, float b, int ma, int mb, float r) {

  float xa = a * r;
  float xb = b * (1. - r);

  float ta = max(a, (xa - xb));
  float tb = max(b, -(xa - xb));

  vec4 cc = vec4(E);
  cc[ma] = ta;
  cc[mb] = tb;

  return cc;
}

// Potential field of the object
// p : point
vec4 Object(vec3 p) {

  float a = SU(Sphere(p, vec3(-2.0, 0.0, 0.0), 3.0), Sphere(p, vec3(-0.0, 0.0, 3.0), 2.0), 0.5);

  float b = Sphere(p, vec3(2.0, 0.0, 0.0), 3.0);

  float r = (sin(iTime) + 1.0) * 0.5;

  vec4 v = Contact(a, b, 1, 2, r);
  v = Difference(v, Box(p, vec3(-0.0, -8.0, 0.0), vec3(7.0)));

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
  float eps = .001;
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
  Ray ray = CreateRay(m, pixel, vec3(24., 0., 5.), vec3(0., 0., 0.));

  // Trace ray

  // Hit and number of steps
  float t;
  int s;

  bool h = SphereTrace(ray, 100., t, s);

  // Position
  vec3 pt = Eval(ray, t);

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
