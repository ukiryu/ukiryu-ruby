# frozen_string_literal: true

require_relative "ffi_helper"
require "fileutils"
require "tmpdir"

RSpec.describe Ukiryu::Ffi::Library do
  let(:vendored) { File.join(Ukiryu::Ffi::VENDOR_DIR, FFI.map_library_name("ukiryu")) }

  it "names the vendored library of this platform, then the system loader" do
    expect(described_class.candidates({})).to eq([vendored, "ukiryu"])
    expect(File.basename(vendored)).to eq(
      { "windows" => "ukiryu.dll", "macos" => "libukiryu.dylib", "linux" => "libukiryu.so" }.fetch(host)
    )
  end

  it "loads the vendored platform library when no path is given" do
    skip "this leg loads UKIRYU_FFI_LIB, not a vendored copy" unless File.file?(vendored)

    expect(described_class.locate({}).path).to eq(vendored)
  end

  it "uses only the explicit UKIRYU_FFI_LIB path" do
    source = Ukiryu::Ffi.library.path
    # Windows keeps a loaded DLL locked until the process exits, so the
    # directory holding the copy is left for the runner to discard there.
    dir = Dir.mktmpdir
    copy = File.join(dir, "copy-#{File.basename(source)}")
    FileUtils.cp(source, copy)
    library = described_class.locate(Ukiryu::Ffi::ENV_LIBRARY => copy)
    expect(library.path).to eq(copy)
    expect(library.abi_version).to eq(Ukiryu::Ffi::ABI_VERSION)
  ensure
    FileUtils.remove_entry(dir) if dir && unix?
  end

  it "does not fall back when the explicit path is missing" do
    missing = File.join(Dir.tmpdir, "ukiryu-missing", FFI.map_library_name("ukiryu"))
    expect { described_class.locate(Ukiryu::Ffi::ENV_LIBRARY => missing) }
      .to raise_error(Ukiryu::Ffi::LibraryNotFound) { |e|
        expect(e.attempts).to eq([[missing, "no such file"]])
      }
  end

  it "rejects a file that is not a loadable library" do
    Dir.mktmpdir do |dir|
      bogus = File.join(dir, FFI.map_library_name("ukiryu"))
      File.write(bogus, "not a library")
      expect { described_class.locate(Ukiryu::Ffi::ENV_LIBRARY => bogus) }
        .to raise_error(Ukiryu::Ffi::LibraryNotFound) { |e|
          expect(e.attempts.map(&:first)).to eq([bogus])
        }
    end
  end

  it "speaks ABI 1 and reports the core version" do
    expect(Ukiryu::Ffi.library.abi_version).to eq(1)
    expect(Ukiryu::Ffi.version).to eq("version" => "0.1.0", "abi_version" => 1)
    expect(Ukiryu::Ffi.available?).to be(true)
  end

  it "runs without the native extension" do
    expect(defined?(Ukiryu::Native)).to be_nil
    expect($LOADED_FEATURES.grep(/ukiryu_native/)).to be_empty
  end
end
