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

// Convert BlobTree field function to signed distance field

// v : Vector storing the value of the field, and the distance to the compact support
// k : Lipschitz constant of the BlobTree
float BlobToSdf(vec2 v, float k) {
  if(v.y < 0.0) {
    return -v.x / k;
  }

  return T / k + v.y;
}

// Signed distance fields

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

// Multiphase 

// Multiphase primitives 
// Mostly binary operators that combine multiphase objects

const float E = 1e4;

int Int(float x) {
  return (x > 0.0) ? int(x) : int(x) - 1;
}

// Checker infinite primitive
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

// Multiphase operators 

// Set one phase
// a : Value.
// m : Phase.
vec4 Set(float a, int m) {
  vec4 pa = vec4(E);
  pa[m] = a;
  return pa;
}

// Keep only one phase 
// a : Multiphase
// m : Phase index
vec4 Keep(vec4 a, int m) {
  vec4 e = vec4(E);
  e[m] = a[m];
  return e;
}

vec4 Shrink(vec4 v) {
  return v + 0.05;
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

// Hybrid operators
// Combine a multiphase object with a simple signed distane field

// Hybrid intersection between a multiphase and a signed distane field
// a : Multiphase
// b : Signed distance field
vec4 Inter(vec4 a, float b) {
  return vec4(max(a.x, b), max(a.y, b), max(a.z, b), max(a.w, b));
}

// Hybrid difference between a multiphase and a signed distane field
// a : Multiphase
// b : Signed distance field
vec4 Difference(vec4 a, float b) {
  return max(a, vec4(-b));
}

// Contact between two phases
// An alternative implementation could be: vec4 Contact(vec4 v, int ma, int mb, float r) 
// a, b : Signed distane fields
// ma, mb : Phase indexes
// r : Contact coefficient
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
