const R = 6371e3;

export function calculateDisplacement(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
) {
  const toRad = (deg: number) => (deg * Math.PI) / 180;

  const φ1 = toRad(lat1);
  const φ2 = toRad(lat2);
  const Δφ = toRad(lat2 - lat1);
  const Δλ = toRad(lon2 - lon1);

  const a =
    Math.sin(Δφ / 2) ** 2 +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) ** 2;
  const distance =
    R *
    (2 * Math.atan2(Math.sqrt(Math.min(1, a)), Math.sqrt(Math.max(0, 1 - a))));

  const y = Math.sin(Δλ) * Math.cos(φ2);
  const x =
    Math.cos(φ1) * Math.sin(φ2) -
    Math.sin(φ1) * Math.cos(φ2) * Math.cos(Δλ);
  const bearing = ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;

  const x_m = parseFloat(
    (distance * Math.sin((bearing * Math.PI) / 180)).toFixed(2),
  );
  const y_m = parseFloat(
    (distance * Math.cos((bearing * Math.PI) / 180)).toFixed(2),
  );

  return {
    distance: parseFloat(distance.toFixed(2)),
    bearing: parseFloat(bearing.toFixed(4)),
    x_m,
    y_m,
  };
}
