class Nummulab < Formula
  desc "Keyboard heatmap & programming tool customizable via Lua"
  homepage "https://github.com/ClopenSet/nummulab"
  url "https://github.com/ClopenSet/nummulab/archive/refs/tags/v1.1.0.tar.gz"
  sha256 "cc0d5a42c58864ce9f9f6827d4f1445e3cc8aa91da194ed2e945b7352d26f4e5"
  license "MIT"
  depends_on "go" => :build

  def install
    # 1. Build the project
    system "make"
    # 2. Install private support library (lsqlite_min.so)
    # We place this in libexec/lsqlite_min so it is hidden from the user's path
    (libexec/"lsqlite_min").install "lsqlite_min/lsqlite_min.so"

    # 3. Install binaries to libexec
    # We install them here so we can create wrapper scripts in 'bin' later
    libexec.install "nummulab"
    libexec.install "viewer/nummulab-heatmap"

    # 4. Install user-modifiable scripts to etc/nummulab
    # Homebrew preserves files in 'etc' across upgrades if the user modifies them
    (etc/"nummulab").install "scripts/nummulab.lua"
    (etc/"nummulab").install "scripts/nummulab_init.sql"

    # 5. Install Documentation
    doc.install "README.md"

    # 6. Create Wrapper for 'nummulab'
    # This sets the specific environment variables required for the main app
    (bin/"nummulab").write <<~EOS
      #!/bin/bash
      export DEFAULT_NUMMULAB_LUA_PATH="#{etc}/nummulab/nummulab.lua"
      export DEFAULT_NUMMULAB_PRIVATE_PLUGIN_PATH="#{libexec}/lsqlite_min"
      export DEFAULT_NUMMULAB_DB_PATH="#{var}/nummulab/nummulab.db"
      export DEFAULT_NUMMULAB_INITSQL_PATH="#{etc}/nummulab/nummulab_init.sql"
      # DEFAULT_NUMMULAB_PUBLIC_PLUGIN_PATH inherits from shell environment
      exec "#{libexec}/nummulab" "$@"
    EOS

    # 7. Create Wrapper for 'nummulab-heatmap'
    # This only needs the DB path
    (bin/"nummulab-heatmap").write <<~EOS
      #!/bin/bash
      export DEFAULT_NUMMULAB_DB_PATH="#{var}/nummulab/nummulab.db"
      exec "#{libexec}/nummulab-heatmap" "$@"
    EOS
  end

  post_install_steps do
    mkdir_p "nummulab", base: :var
    mkdir_p "nummulab", base: :etc
  end

  # Define the background service
  service do
    run [opt_libexec/"nummulab"]

    environment_variables(
      DEFAULT_NUMMULAB_LUA_PATH:            etc/"nummulab/nummulab.lua",
      DEFAULT_NUMMULAB_PRIVATE_PLUGIN_PATH: opt_libexec/"lsqlite_min",
      DEFAULT_NUMMULAB_DB_PATH:             var/"nummulab/nummulab.db",
      DEFAULT_NUMMULAB_INITSQL_PATH:        etc/"nummulab/nummulab_init.sql",
    )

    keep_alive true
    log_path var/"log/nummulab.log"
    error_log_path var/"log/nummulab.error.log"
    working_dir var/"nummulab"
  end

  def caveats
    <<~EOS
      Initialize the local database before starting the service:
        nummulab init

      Existing data is preserved during upgrades. To remove it, run
      `nummulab delete` before uninstalling, or remove it manually from:
        #{var}/nummulab

      The Lua configuration is installed at:
        #{etc}/nummulab/nummulab.lua

      To monitor keyboard events, grant Input Monitoring and Accessibility
      permissions to:
        #{opt_libexec}/nummulab

      These permissions are managed in System Settings > Privacy & Security.
      macOS may require them to be granted again after an upgrade. Keyboard
      analytics and configuration remain on this Mac.

      Start the background service with:
        brew services start nummulab

      Open the interactive heatmap with:
        nummulab-heatmap

      Documentation is available at:
        #{doc}/README.md
    EOS
  end
end
