//go:build windows

package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/ddev/ddev/pkg/exec"
	"github.com/ddev/ddev/pkg/fileutil"
	"github.com/stretchr/testify/require"
)

const (
	testDistroName = "Ubuntu-22.04"
	installerPath  = "../.gotmp/bin/windows_amd64/ddev_windows_amd64_installer.exe"
)

// TestWindowsInstallerWSL2DockerCE tests the WSL2 with Docker CE installation path
func TestWindowsInstallerWSL2DockerCE(t *testing.T) {
	if os.Getenv("DDEV_TEST_USE_REAL_INSTALLER") == "" {
		t.Skip("Skipping installer test, set DDEV_TEST_USE_REAL_INSTALLER=true to run")
	}

	require := require.New(t)

	// Create fresh test WSL2 distro
	cleanupTestEnv(t)
	createTestWSL2Distro(t)
	//t.Cleanup(func() {
	//	// Cleanup any existing test distro
	//	cleanupTestEnv(t)
	//})

	// Get absolute path to installer
	wd, err := os.Getwd()
	require.NoError(err)
	installerFullPath := filepath.Join(wd, installerPath)
	require.True(fileutil.FileExists(installerFullPath), "Installer not found at %s", installerFullPath)

	// Run installer with WSL2 Docker CE option
	t.Logf("Running installer: %s", installerFullPath)
	out, err := exec.RunHostCommand(installerFullPath, "/docker-ce", fmt.Sprintf("/distro=%s", testDistroName), "/S")
	require.NoError(err, "Installer failed: %v, output: %s", err, out)
	t.Logf("Installer output: %s", out)

	// Immediately check if ddev is available to verify installer waited for completion
	out, err = exec.RunHostCommand("wsl.exe", "-d", testDistroName, "bash", "-c", "ddev version")
	if err != nil {
		t.Logf("DDEV not immediately available after installer - installer may not be waiting: %v, output: %s", err, out)
	} else {
		t.Logf("DDEV immediately available after installer - installer properly waited for completion")
	}

	// Test that ddev is installed and working
	testDdevInstallation(t)

	// Test basic ddev functionality
	testBasicDdevFunctionality(t)
}

// Helper functions

// cleanupTestEnv removes the test WSL2 distro and runs the uninstaller if it exists
func cleanupTestEnv(t *testing.T) {
	t.Logf("Cleaning up test environment")

	// First, run the uninstaller to clean up Windows-side components
	// Try common installation locations for the uninstaller
	possiblePaths := []string{
		`C:\Program Files\DDEV\ddev_uninstall.exe`,
	}

	var uninstallerPath string
	for _, path := range possiblePaths {
		if fileutil.FileExists(path) {
			uninstallerPath = path
			break
		}
	}

	if uninstallerPath != "" {
		t.Logf("Running uninstaller: %s", uninstallerPath)
		out, err := exec.RunHostCommand(uninstallerPath, "/S")
		t.Logf("Uninstaller result - err: %v, output: %s", err, out)
	} else {
		t.Logf("No uninstaller found (DDEV may not be installed yet)")
	}

	// Clean up test distro
	t.Logf("Cleaning up test distro: %s", testDistroName)

	// Check if distro exists
	out, err := exec.RunHostCommand("wsl.exe", "-l", "-q")
	if err != nil {
		t.Logf("Failed to list WSL distros: %v", err)
		return
	}

	// Convert UTF-16 output to UTF-8 by removing null bytes
	cleanOut := strings.ReplaceAll(out, "\x00", "")
	//t.Logf("WSL distros list: %q", cleanOut)

	if strings.Contains(cleanOut, testDistroName) {

		// Get distro back to a fairly normal pre-ddev state.
		// Makes test run much faster than completely deleting the distro.
		out, _ := exec.RunHostCommand("wsl.exe", "-d", testDistroName, "bash", "-c", "(ddev poweroff || true) && (ddev stop --unlist -a) && rm -rf ~/tp")
		t.Logf("ddev poweroff: err=%v, output: %s", err, out)

		out, err := exec.RunHostCommand("wsl.exe", "-d", testDistroName, "-u", "root", "bash", "-c", "(mkcert -uninstall || true) && (apt-get remove -y ddev docker-ce-cli docker-ce || true)")
		t.Logf("distro cleanup: err=%v, output: %s", err, out)

		//t.Logf("Test distro %s exists, attempting to remove", testDistroName)
		// Unregister (delete) the distro
		//out, err = exec.RunHostCommand("wsl.exe", "--unregister", testDistroName)
		//if err != nil {
		//	t.Logf("Failed to unregister distro %s: %v, output: %s", testDistroName, err, out)
		//} else {
		//	t.Logf("Successfully removed test distro: %s", testDistroName)
		//}
	}
}

// createTestWSL2Distro creates a fresh Ubuntu 22.04 WSL2 distro for testing
func createTestWSL2Distro(t *testing.T) {
	require := require.New(t)
	t.Logf("Creating or updating test distro: %s", testDistroName)

	// Install the WSL distro without launching
	t.Logf("Installing WSL distro %s", testDistroName)
	out, err := exec.RunHostCommand("wsl.exe", "--install", testDistroName, "--no-launch")
	require.NoError(err, "Failed to install WSL distro: %v, output: %s", err, out)

	// Complete distro setup with root user (avoids interactive user setup)
	t.Logf("Completing distro setup with root user only")
	userProfile := os.Getenv("USERPROFILE")
	// Convert Ubuntu-22.04 to ubuntu2204.exe
	exeName := strings.ToLower(strings.ReplaceAll(strings.ReplaceAll(testDistroName, "-", ""), ".", "")) + ".exe"
	ubuntuExePath := filepath.Join(userProfile, "AppData", "Local", "Microsoft", "WindowsApps", exeName)
	out, err = exec.RunHostCommand(ubuntuExePath, "install", "--root")
	// Note: distro.exe install --root is undocumented but works, though it returns non-zero exit code
	t.Logf("Distro setup output: %s, error: %v", out, err)

	// Wait a moment for the distro to be fully registered
	time.Sleep(1 * time.Second)

	// Create an unprivileged default user
	t.Logf("Creating unprivileged default user if it doesn't exist")
	out, err = exec.RunHostCommand("wsl.exe", "-d", testDistroName, "-u", "root", "bash", "-c", "if ! id -u testuser; then useradd -m -s /bin/bash testuser && echo 'testuser:testpass' | chpasswd && usermod -aG sudo testuser; fi")
	require.NoError(err, "Failed to create test user: %v, output=%v", err, out)

	// Set testuser as the default user using wsl --manage
	t.Logf("Setting testuser as default user")
	_, err = exec.RunHostCommand("wsl.exe", "--manage", testDistroName, "--set-default-user", "testuser")
	require.NoError(err, "Failed to set default user: %v", err)

	t.Logf("Test WSL2 distro %s set up successfully", testDistroName)
}

// testDdevInstallation verifies that ddev is properly installed in WSL2
func testDdevInstallation(t *testing.T) {
	require := require.New(t)
	t.Logf("Testing ddev installation in %s", testDistroName)

	// Test ddev version
	out, err := exec.RunHostCommand("wsl.exe", "-d", testDistroName, "ddev", "version")
	require.NoError(err, "ddev version failed: %v, output: %s", err, out)
	require.Contains(out, "DDEV version")
	t.Logf("ddev version output: %s", out)

	// Test ddev-hostname
	out, err = exec.RunHostCommand("wsl.exe", "-d", testDistroName, "ddev-hostname", "--help")
	require.NoError(err, "ddev-hostname failed: %v, output: %s", err, out)
	t.Logf("ddev-hostname available")
}

// testBasicDdevFunctionality tests basic ddev project creation and start
func testBasicDdevFunctionality(t *testing.T) {
	require := require.New(t)
	t.Logf("Testing basic ddev functionality in %s", testDistroName)

	projectDir := "~/tp"
	projectName := "tp"

	// Clean up any existing test project
	_, _ = exec.RunHostCommand("wsl.exe", "-d", testDistroName, "rm", "-rf", projectDir)

	// Create test project directory
	out, err := exec.RunHostCommand("wsl.exe", "-d", testDistroName, "mkdir", "-p", projectDir)
	require.NoError(err, "Failed to create project directory: %v, output: %s", err, out)

	// Create a simple index.html
	_, err = exec.RunHostCommand("wsl.exe", "-d", testDistroName, "bash", "-c", fmt.Sprintf("echo 'Hello from DDEV!' > %s/index.html", projectDir))
	require.NoError(err, "Failed to create index.html: %v", err)

	// Initialize ddev project
	out, err = exec.RunHostCommand("wsl.exe", "-d", testDistroName, "bash", "-c", fmt.Sprintf("cd %s && ddev config --auto && ddev start -y", projectDir))
	require.NoError(err, "ddev config/start failed: %v, output: %s", err, out)
	t.Logf("ddev config/start output: %s", out)

	// Test HTTP response from inside WSL distro
	out, err = exec.RunHostCommand("wsl.exe", "-d", testDistroName, "bash", "-c", fmt.Sprintf("curl -s https://%s.ddev.site", projectName))
	require.NoError(err, "curl to HTTPS site failed: %v, output: %s", err, out)
	require.Contains(out, "Hello from DDEV!")
	t.Logf("HTTPS site responding correctly")

	// Test using windows PowerShell to check HTTPS
	out, err = exec.RunHostCommand("powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", fmt.Sprintf("Invoke-RestMethod 'https://%s.ddev.site' -ErrorAction Stop", projectName))
	require.NoError(err, "HTTPS check failed: %v, output: %s", err, out)
	require.Contains(out, "Hello from DDEV!")
	t.Logf("Project working and accessible from Windows")

	_, _ = exec.RunHostCommand("wsl.exe", "-d", testDistroName, "bash", "-c", "ddev poweroff")

	t.Logf("Basic ddev functionality test completed successfully")
}

// isDockerDesktopAvailable checks if Docker Desktop is installed and running
func isDockerDesktopAvailable() bool {
	// Check if Docker Desktop process is running
	out, err := exec.RunHostCommand("tasklist.exe", "/FI", "IMAGENAME eq Docker Desktop.exe")
	if err != nil {
		return false
	}
	return strings.Contains(out, "Docker Desktop.exe")
}
