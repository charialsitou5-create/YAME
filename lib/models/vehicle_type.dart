import '../core/constants/app_strings.dart';

/// Type de véhicule demandé pour une course.
enum VehicleType {
  car,
  moto;

  String get label => switch (this) {
        VehicleType.car => AppStrings.bookingVehicleCar,
        VehicleType.moto => AppStrings.bookingVehicleMoto,
      };
}
