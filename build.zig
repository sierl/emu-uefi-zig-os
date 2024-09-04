const std = @import("std");

pub fn build(b: *std.Build) void {
    const loader_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .uefi,
        .abi = .msvc,
        .ofmt = .coff,
    });

    const optimize = b.standardOptimizeOption(.{});

    const loader = b.addExecutable(.{
        .name = "bootx64",
        .root_source_file = b.path("loader/main.zig"),
        .target = loader_target,
        .optimize = optimize,
    });

    b.installArtifact(loader);

    const fs_tree = b.addWriteFiles();
    _ = fs_tree.addCopyFile(loader.getEmittedBin(), "efi/boot/bootx64.efi");

    const qemu = b.addSystemCommand(&.{"qemu-system-x86_64"});
    qemu.addArgs(&.{ "-bios", "vendor/ovmf_bios64.bin" });
    qemu.addArg("-hdd");
    qemu.addPrefixedDirectoryArg("fat:rw:", fs_tree.getDirectory());
    // qemu.addArgs(&.{ "-serial", "stdio" });
    qemu.addArgs(&.{ "-display", "gtk" });
    qemu.addArgs(&.{ "-net", "none" });

    const qemu_step = b.step("qemu", "Run the loader in QEMU");
    qemu_step.dependOn(&qemu.step);
}
