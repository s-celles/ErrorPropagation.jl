#include <math.h>
void ohms_law_evaluator(double* du, const double RHS1, const double RHS2, const double RHS3, const double RHS4) {
  du[0] = RHS1 / RHS2;
  du[1] = hypot((-1 * RHS1 * RHS4) / (RHS2 * RHS2), RHS3 / RHS2);
}
