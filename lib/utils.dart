import 'dart:math' as math;

double normalizeAngle(double a) {
  double val = a % (2 * math.pi);
  if (val < 0) val += 2 * math.pi;
  return val;
}
