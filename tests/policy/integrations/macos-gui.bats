#!/usr/bin/env bats
# bats file_tags=suite:policy

load ../../test_helper.bash

@test "[POLICY-ONLY] enable=macos-gui adds GUI grants, implies clipboard, and does not inject electron" {
  local profile
  profile="$(safehouse_profile --enable=macos-gui)"

  sft_assert_includes_source "$profile" "55-integrations-optional/macos-gui.sb"
  sft_assert_includes_source "$profile" "55-integrations-optional/clipboard.sb"
  sft_assert_omits_source "$profile" "55-integrations-optional/electron.sb"
}

# com.apple.lsd.modifydb lets a process persistently rewrite default
# file-type/URL-scheme handlers, so a later user double-click can launch an
# unsandboxed app. Only the opt-in launch-services integration may grant it.
@test "[POLICY-ONLY] GUI, clipboard, and app profiles do not grant lsd.modifydb" {
  local profile

  profile="$(safehouse_profile --enable=electron,chromium-headless,chromium-full,all-agents,all-apps)"

  sft_assert_includes_source "$profile" "55-integrations-optional/macos-gui.sb"
  sft_assert_includes_source "$profile" "55-integrations-optional/clipboard.sb"
  sft_assert_not_contains "$profile" '(global-name "com.apple.lsd.modifydb")'
}

@test "[POLICY-ONLY] enable=launch-services still grants lsd.modifydb" {
  local profile

  profile="$(safehouse_profile --enable=launch-services)"

  sft_assert_contains "$profile" '(global-name "com.apple.lsd.modifydb")'
}

# NOTE: If this regresses, the bogus scheme below is registered in the user's
#       Launch Services database (pointing at TextEdit). It is harmless.
@test "[EXECUTION] macos-gui cannot rewrite Launch Services default handlers" {
  sft_require_cmd_or_skip osascript

  safehouse_denied \
    --enable=macos-gui \
    -- /usr/bin/osascript -l JavaScript -e '
      ObjC.import("CoreServices");
      var status = $.LSSetDefaultHandlerForURLScheme($("x-safehouse-test-modifydb"), $("com.apple.TextEdit"));
      if (status !== 0) { throw new Error("LSSetDefaultHandlerForURLScheme denied: " + status); }'
}
