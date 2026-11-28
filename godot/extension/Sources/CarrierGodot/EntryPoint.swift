import SwiftGodot

/// The library's entry point, which `NoCarrier.gdextension` names. It is
/// what SwiftGodot's `#initSwiftExtension` macro writes, by hand, because
/// the macro's code has no `unsafe` marks and this package builds with
/// strict memory safety.
@_cdecl("swift_entry_point")
public func enterExtension(interface: OpaquePointer?, library: OpaquePointer?, extension: OpaquePointer?) -> UInt8 {
    // unsafe: Godot hands the extension these C pointers; SwiftGodot's only
    // way to start the module takes them as they are.
    guard let library = unsafe library, let interface = unsafe interface, let ext = unsafe `extension` else {
        GD.printErr("NO CARRIER: Godot did not pass the extension pointers")
        return 0
    }
    let types: [ExtensionInitializationLevel: [Object.Type]]
    do {
        types = try [NoCarrierGame.self].prepareForRegistration()
    } catch {
        GD.printErr("NO CARRIER: cannot register the extension types: \(error)")
        return 0
    }
    unsafe initializeSwiftModule(
        interface, library, ext,
        initHook: { level in types[level]?.forEach(register) },
        deInitHook: { level in types[level]?.reversed().forEach(unregister) },
        minimumInitializationLevel: minimumInitializationLevel(for: types))
    return 1
}
