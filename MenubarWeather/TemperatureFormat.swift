/// Rounded temperature with a degree sign; never renders "-0°".
func formatTemperature(_ value: Double) -> String {
    let rounded = Int(value.rounded())
    return "\(rounded)°"
}
