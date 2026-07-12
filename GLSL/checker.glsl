struct Ray {
  vec3 o;
  vec3 d;
};

vec3 Eval(Ray ray, float t) {
  return ray.o + ray.d * t;
}

int hash_ivec3(ivec3 v) {
  int h = v.x * 73856093 ^ v.y * 19349663 ^ v.z * 83492791;

  h ^= (h >> 13);
  h *= 1274126177;
  h ^= (h >> 16);

  return h;
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

const int Steps = 200;
const float Epsilon = .001;// Marching epsilon

// Primitives ------------------------------------------------------------------------------------

const float E = 1e4;

float Sphere(vec3 p, vec3 c, float R) {
  float d = length(p - c) - R;
  return d;
}

int Int(float x) {
  return (x > 0.0) ? int(x) : int(x) - 1;
}

// New checker infinite primitive
// p : point
// a,b: materials
vec4 Checker(vec3 p, int a, int b) {
  vec3 q = fract(p);
  int k = (Int(p.x) + Int(p.y) + Int(p.z)) % 2;

  vec3 e = min(q, 1. - q);
  float d = min(min(e.x, e.y), e.z);

  vec4 v = vec4(E);
  d = (k == 0) ? d : -d;
  v[a] = d;
  v[b] = -d;
  return v;
}

// New checker infinite primitive
// p : point
// a,b: materials
// 1.0 is a lower distance bound (a better one exists at the expense of more computations)
// The loop with set 0.0 as distance for the phase in the center cell, so recompute it after instead of using if statement
vec4 Checker(vec3 p, int n) {
  vec3 u = fract(p);
  vec3 v = 1.0 - u;

  ivec3 c = ivec3(Int(p.x), Int(p.y), Int(p.z));

  vec4 r = vec4(E);

  for(int i = 0; i < n; i++) {
    r[i] = 1.0;
  }
  // Loop for 1-neighboring cells and compute phase distance, including center cell
  for(int i = -1; i < 2; i++) {
    for(int j = -1; j < 2; j++) {
      for(int k = -1; k < 2; k++) {
        ivec3 ijk = ivec3(i, j, k);
        ivec3 cijk = c + ijk;
        int aijk = hash_ivec3(cijk) % n;
        vec3 dijk = vec3((ijk.x < 0) ? u.x : ((ijk.x) >= 1 ? v.x : 0.0), ((ijk.y) < 0) ? u.y : ((ijk.y) >= 1 ? v.y : 0.0), ((ijk.z) < 0) ? u.z : ((ijk.z) >= 1 ? v.z : 0.0));
        r[aijk] = min(r[aijk], length(dijk));
      }
    }
  } 
  // Set phase (negative) at center
  int a = hash_ivec3(c) % n;
  vec3 e = min(u, v);
  float d = min(min(e.x, e.y), e.z);
  r[a] = -d;

  return r;
}

// Point skeleton
// p : point
// c : center of skeleton
// R : radius
// m : Phase index
vec4 Sphere(vec3 p, vec3 c, float R, int m) {
  vec4 v = vec4(E);
  float d = Sphere(p, c, R);
  v[m] = d;
  return v;
}

// Operators ----------------------------------------------------------------------------------
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

// Under
// a : field function of left sub-tree
// b : field function of right sub-tree
vec4 Under(vec4 a, vec4 b) {
 // Same material
  return vec4(D(U(a.x, b.x), U(a.y, a.z, a.w)), D(U(a.y, b.y), U(a.x, a.z, a.w)), D(U(a.z, b.z), U(a.x, a.y, a.w)), D(U(a.w, b.w), U(a.x, a.y, a.z)));
}

vec4 Inter(vec4 a, float b) {
  return vec4(max(a.x, b), max(a.y, b), max(a.z, b), max(a.w, b));
}

// Under with only one material : c'est comme dire que pour i!=m, on a l'infini
// a : field function of left sub-tree
// b : field function of right sub-tree
vec4 Under(vec4 a, float b, int m) {
  if(m == 0) {
    return vec4(D(U(a.x, b), U(a.y, a.z, a.w)), D(a.y, U(a.x, a.z, a.w)), D(a.z, U(a.x, a.y, a.w)), D(a.w, U(a.x, a.y, a.z)));
  } else if(m == 1) {
    return vec4(D(a.x, U(a.y, a.z, a.w)), D(U(a.y, b), U(a.x, a.z, a.w)), D(a.z, U(a.x, a.y, a.w)), D(a.w, U(a.x, a.y, a.z)));
  } else if(m == 2) {
    return vec4(D(a.x, U(a.y, a.z, a.w)), D(a.y, U(a.x, a.z, a.w)), D(U(a.z, b), U(a.x, a.y, a.w)), D(a.w, U(a.x, a.y, a.z)));
  } else {
    return vec4(D(a.x, U(a.y, a.z, a.w)), D(a.y, U(a.x, a.z, a.w)), D(a.z, U(a.x, a.y, a.w)), D(U(a.w, b), U(a.x, a.y, a.z)));
  }
}

// From a object a, change material ma by material mb in the region defined by b
vec4 Change(vec4 a, float b, int ma, int mb) {
  float aa[4] = float[4](a.x, a.y, a.z, a.w);
  float cc[4] = aa;

// Substract object only from ma
  cc[ma] = D(aa[ma], b); // Remove material
  cc[mb] = U(aa[mb], I(aa[ma], b)); // Union of mb, with the new intersection
  return vec4(cc[0], cc[1], cc[2], cc[3]);
}

vec4 Extract(vec4 a, int m) {
  float aa[4] = float[4](a.x, a.y, a.z, a.w);
  float cc[4] = float[4](E, E, E, E);

  cc[m] = aa[m];
  return vec4(cc[0], cc[1], cc[2], cc[3]);
}

// Over
// a,b : field functions of left and right sub-trees
vec4 Over(vec4 a, vec4 b) {
  return Under(b, a);
}

vec4 Keep(vec4 v, int m) {
  float cc[4] = float[4](E, E, E, E);
  cc[m] = v[m];
  return vec4(cc[0], cc[1], cc[2], cc[3]);
}

vec4 Remove(vec4 v, int m) {
  float cc[4] = float[4](v.x, v.y, v.z, v.w);
  cc[m] = E;
  return vec4(cc[0], cc[1], cc[2], cc[3]);
}

vec4 Difference(vec4 a, float b) {
  return vec4(max(a.x, -b), max(a.y, -b), max(a.z, -b), max(a.w, -b));
}

// Potential field of the object
// p : point
vec4 Object(vec3 p) {
  p.z = -p.z; 
  // 1 vert 2 jaune 3 bleu 0 rouge

  // Blobby shape
  float b = SU(Sphere(p, vec3(-4., -1., -1.), 3.0), Sphere(p, vec3(2., 2., 2.), 4.0), 1.0);

  // Use either checker infinite primitive
  //vec4 v = Checker(p, 1, 2);
  vec4 v = Checker(p, 4);
  v = Inter(v, b); 

  // Remove two phases just to see the consistent remaining two-phase fields
  v = Remove(v, 2);
  v = Remove(v, 1);

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
