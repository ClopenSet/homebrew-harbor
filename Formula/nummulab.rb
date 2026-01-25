class Nummulab < Formula
  desc "Keyboard heatmap & programming tool customizable via Lua"
  homepage "https://github.com/ClopenSet/nummulab"
  url "https://github.com/ClopenSet/nummulab/archive/refs/tags/v1.0.tar.gz"
  license "MIT"
  depends_on "go" => :build
  sha256 "53a27d44ba696ca2574b53aa37c45de0bd2107968479569a60fb4e0e17706cd5"

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

  def post_install
    # Ensure the database directory exists
    (var/"nummulab").mkpath
    # Ensure the config directory exists (in case install skipped it)
    (etc/"nummulab").mkpath
  end

  # Define the background service
  service do
    run [opt_libexec/"nummulab"]

    environment_variables(
      DEFAULT_NUMMULAB_LUA_PATH: etc/"nummulab/nummulab.lua",
      DEFAULT_NUMMULAB_PRIVATE_PLUGIN_PATH: libexec/"lsqlite_min",
      DEFAULT_NUMMULAB_DB_PATH: var/"nummulab/nummulab.db",
      DEFAULT_NUMMULAB_INITSQL_PATH: etc/"nummulab/nummulab_init.sql"
    )
    
    keep_alive true
    log_path var/"log/nummulab.log"
    error_log_path var/"log/nummulab.error.log"
    working_dir var/"nummulab"
  end

  def caveats
    red = "\033[31m"
    bold = "\033[1m"
    reset = "\033[0m"

    <<~EOS

      1. Initialization:
         Before running the service, please initialize the database by running:
         $ nummulab init
          This database will be initialized in the #{var}. When uninstalling, no caveat will be triggered. You should run 'nummulab delete' or manually delete it.
          If a previous database is located here, this init command won't do anything.

      2. Configuration:
         You can modify the behavior of the application by editing:
         #{etc}/nummulab/nummulab.lua (It is configured to be a keylogger to show its ability.)

         You can check the documentation at:
         #{doc}/README.md

      #{red} #{bold}
      3. This software requires high-level privileges to monitor keyboard events. However, all data and logic are preserved locally and therefore it won't cast any risks.
        If upgraded or reinstalled, the previous permissions should be cancelled and regranted to the new software.

        Please manually grant permissions in 'System Settings -> Privacy & Security':
        1. System Settings > Privacy & Security > Input Monitoring: Add and enable '#{opt_libexec}/nummulab'
        2. System Settings > Privacy & Security > Accessibility: Add and enable '#{opt_libexec}/nummulab'

        Click your 'Macintosh HD' > /opt (If not shown, use Command + Shift + Dot to reveal the hidden ) > ... [Provided that you install your homebrew here]
      #{reset}

      4. Service:
        To start nummulab now and restart at login:
        $ brew services start nummulab
        $ brew services 
        If 'started' are shown, it's started successfully. 
      
      5. Usage:
        An interactive heatmap is embedded. Use  #{red}#{bold}'nummulab-heatmap'#{reset} to see the result.
        Modify the script and restart the service to change its behavior. If temporarily tested, use the #{red}#{bold}'nummulab'#{reset} cli which needs no options and controlled completely by the script.
        See the docs at #{doc}/README.md for further informations.
      
    EOS
  end

end
