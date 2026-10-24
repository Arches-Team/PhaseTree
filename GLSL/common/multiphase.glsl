// Multiphase signed distance fields
// A multiphase value is stored as a vec4, i.e., up to four phases
// An absent phase is set to the large value E

// The body is skipped when the code is compiled as GLSL ES 1.00, i.e., when the VS Code shader-toy extension test compiles this file on its own
#if !defined(MULTIPHASE_GLSL) && __VERSION__ >= 300
#define MULTIPHASE_GLSL

#include "sdf.glsl"

// Infinity!
const float E = 1e4;

// Integer part rounded towards minus infinity
// x : Value
int Int(float x) {
  return int(floor(x));
}

// Hash function for integer cell coordinates
// v : Cell coordinates
int Hash(ivec3 v) {
  int h = v.x * 73856093 ^ v.y * 19349663 ^ v.z * 83492791;

  h ^= (h >> 13);
  h *= 1274126177;
  h ^= (h >> 16);

  return h;
}

// Queries

// Get minimum phase, i.e., the signed distance to the union of all phases
// v : Multiphase value
float MinPhase(vec4 v) {
  return min(min(v.x, v.y), min(v.z, v.w));
}

// Get index of the minimum phase, i.e., the phase at the point
// v : Multiphase value
int MinIndex(vec4 v) {
  return (v.y < v.x) ? ((v.z < v.y) ? ((v.w < v.z) ? 3 : 2) : ((v.w < v.y) ? 3 : 1)) : ((v.z < v.x) ? ((v.w < v.z) ? 3 : 2) : ((v.w < v.x) ? 3 : 0));
}

// Get i-th element of multiphase, obvious, provided here only in case of array implementation
// v : Multiphase value
// i : Phase index
float GetIth(vec4 v, int i) {
  return v[i];
}

// Phase operators

// Set phase, i.e., promote a signed distance field to a multiphase object with a single phase
// a : Signed distance field
// m : Phase index
vec4 Set(float a, int m) {
  vec4 v = vec4(E);
  v[m] = a;
  return v;
}

// Get phase, i.e., keep only one phase
// v : Multiphase value
// m : Phase index
vec4 Get(vec4 v, int m) {
  return Set(v[m], m);
}

// Remove one phase
// v : Multiphase value
// m : Phase index
vec4 Remove(vec4 v, int m) {
  v[m] = E;
  return v;
}

// Shrink all phases
// v : Multiphase value
// r : Offset
vec4 Shrink(vec4 v, float r) {
  return v + r;
}

// Multiphase primitives

// Infinite two-phase checker with unit cells
// p : Point
// a, b : Phase indexes
vec4 Checker(vec3 p, int a, int b) {
  vec3 q = fract(p);
  int k = (Int(p.x) + Int(p.y) + Int(p.z)) & 1;

  vec3 e = min(q, 1. - q);
  float d = min(min(e.x, e.y), e.z);

  vec4 v = vec4(E);
  d = (k == 0) ? d : -d;
  v[a] = d;
  v[b] = -d;
  return v;
}

// Infinite checker with unit cells randomly assigned to n phases
// 1.0 is a lower distance bound (a better one exists at the expense of more computations)
// The loop sets 0.0 as distance for the phase of the center cell, so it is recomputed after the loop instead of using an if statement
// p : Point
// n : Number of phases
vec4 Checker(vec3 p, int n) {
  vec3 u = fract(p);
  vec3 v = 1.0 - u;

  ivec3 c = ivec3(Int(p.x), Int(p.y), Int(p.z));

  vec4 r = vec4(E);

  for(int i = 0; i < n; i++) {
    r[i] = 1.0;
  }
  // Loop over the neighboring cells and compute the phase distances, including the center cell
  for(int i = -1; i < 2; i++) {
    for(int j = -1; j < 2; j++) {
      for(int k = -1; k < 2; k++) {
        ivec3 ijk = ivec3(i, j, k);
        int aijk = (Hash(c + ijk) & 0x7fffffff) % n;
        vec3 dijk = vec3((ijk.x < 0) ? u.x : ((ijk.x >= 1) ? v.x : 0.0), (ijk.y < 0) ? u.y : ((ijk.y >= 1) ? v.y : 0.0), (ijk.z < 0) ? u.z : ((ijk.z >= 1) ? v.z : 0.0));
        r[aijk] = min(r[aijk], length(dijk));
      }
    }
  }
  // Set phase (negative) at center
  int a = (Hash(c) & 0x7fffffff) % n;
  vec3 e = min(u, v);
  float d = min(min(e.x, e.y), e.z);
  r[a] = -d;

  return r;
}

// Infinite two-phase wavy slabs
//    p : Point
// a, b : Phase indexes
//   uz : Normal direction of the slabs
//    e : Thickness
vec4 Slicer(vec3 p, int a, int b, vec3 uz, float e) {
  vec3 ux = normalize(vec3(-uz.y, uz.x, 0.0));
  float x = dot(ux, p);

  // The Lipschitz factor of the warping is not taken into account here
  p -= 0.5 * e * sin(x / (0.5 * e)) * uz;

  float d = dot(uz, p);

  int k = Int(d / e) & 1;
  d = fract(d / e) * e;
  d = min(d, e - d);

  vec4 v = vec4(E);
  if(k == 0)
    d = -d;
  v[a] = d;
  v[b] = -d;
  return v;
}

// Multiphase operators
// Mostly binary operators that combine multiphase objects

// Under
// a : Field function of left sub-tree
// b : Field function of right sub-tree, placed under a
vec4 Under(vec4 a, vec4 b) {
  // Union of the other phases of a, computed with pairwise minima (linear instead of quadratic cost)
  float a01 = min(a.x, a.y);
  float a23 = min(a.z, a.w);
  vec4 o = vec4(min(a.y, a23), min(a.x, a23), min(a01, a.w), min(a01, a.z));

  // Same phase union, minus the other phases of a
  return max(min(a, b), -o);
}

// Under with a single-phase field, i.e., all the other phases of b are infinite
// a : Field function of left sub-tree
// b : Signed distance field of right sub-tree
// m : Phase index of b
vec4 Under(vec4 a, float b, int m) {
  return Under(a, Set(b, m));
}

// Over
// a : Field function of left sub-tree
// b : Field function of right sub-tree, placed over a
vec4 Over(vec4 a, vec4 b) {
  return Under(b, a);
}

// Contact between two phases
//   a, b : Signed distance fields
// ma, mb : Phase indexes
//      r : Contact coefficient in [0, 1]
vec4 Contact(float a, float b, int ma, int mb, float r) {
  // Separation field
  float s = a * r - b * (1. - r);

  vec4 v = vec4(E);
  v[ma] = max(a, s);
  v[mb] = max(b, -s);
  return v;
}

// Smooth contact between two phases, the union of both phases is a smooth union
//   a, b : Signed distance fields
// ma, mb : Phase indexes
//      r : Blending radius
//      c : Contact coefficient in [0, 1]
vec4 ContactSmooth(float a, float b, int ma, int mb, float r, float c) {
  // Separation field
  float s = a * c - b * (1. - c);

  // Smooth union instead of working with a and b directly
  float u = SU(a, b, r);

  vec4 v = vec4(E);
  v[ma] = max(u, s);
  v[mb] = max(u, -s);
  return v;
}

// Hybrid operators
// Combine a multiphase object with a signed distance field

// Hybrid intersection between a multiphase object and a signed distance field
// a : Multiphase value
// b : Signed distance field
vec4 Intersection(vec4 a, float b) {
  return max(a, vec4(b));
}

// Hybrid difference between a multiphase object and a signed distance field
// a : Multiphase value
// b : Signed distance field
vec4 Difference(vec4 a, float b) {
  return max(a, vec4(-b));
}

// Localized phase change, phase ma is replaced by phase mb inside the region defined by b
//      a : Multiphase value
//      b : Signed distance field
// ma, mb : Phase indexes
vec4 Change(vec4 a, float b, int ma, int mb) {
  vec4 c = a;
  // Remove the region from phase ma
  c[ma] = D(a[ma], b);
  // Add the intersection of phase ma and the region to phase mb
  c[mb] = U(a[mb], I(a[ma], b));
  return c;
}

#endif
