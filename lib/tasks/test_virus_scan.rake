# frozen_string_literal: true

namespace :test do
  desc "Test virus scanning with EICAR test file (simulates virus detection)"
  task virus_scan: :environment do
    puts "\n" + "=" * 70
    puts "CLAMAV VIRUS SCANNING TEST"
    puts "=" * 70

    # Create temp directory for test files
    test_dir = Rails.root.join("tmp", "virus_scan_test")
    FileUtils.mkdir_p(test_dir)

    begin
      puts "\n1. Testing ClamAV availability..."
      if Clamby.clamav_installed?
        puts "   ✓ ClamAV is installed"
        puts "   Version: #{`clamscan --version`.strip}"
      else
        puts "   ✗ ClamAV is NOT installed"
        puts "   Install ClamAV to run this test:"
        puts "   - macOS: brew install clamav"
        puts "   - Ubuntu/Debian: apt-get install clamav"
        exit 1
      end

      # Test 1: Clean file
      puts "\n2. Testing clean file scan..."
      clean_file = test_dir.join("clean_test.txt")
      File.write(clean_file, "This is a clean test file with no viruses.")

      scanner = ImageVirusScanner.new(clean_file.to_s)
      result = scanner.call

      if result
        puts "   ✓ Clean file passed scan (as expected)"
      else
        puts "   ✗ Clean file failed scan (unexpected!)"
      end

      # Test 2: EICAR test virus
      # EICAR is a standard test string that antivirus software detects
      # It's NOT a real virus, just a test pattern
      puts "\n3. Testing EICAR test virus detection..."
      puts "   Creating EICAR test file..."
      puts "   (This is NOT a real virus - it's a standard AV test string)"

      eicar_file = test_dir.join("eicar_test.txt")
      # EICAR test string - standard antivirus test file
      eicar_string = 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
      File.write(eicar_file, eicar_string)

      puts "   Scanning EICAR test file..."
      scanner = ImageVirusScanner.new(eicar_file.to_s)

      begin
        scanner.call
        puts "   ✗ EICAR file was NOT detected (ClamAV may not be updated)"
        puts "   Run 'freshclam' to update virus database"
      rescue ImageVirusScanner::VirusDetectedError => e
        puts "   ✓ EICAR test virus detected correctly!"
        puts "   Message: #{e.message}"
      rescue ImageVirusScanner::ScanFailedError => e
        puts "   ✗ Scan failed with error: #{e.message}"
      end

      # Test 3: Simulate scan failure (missing file)
      puts "\n4. Testing error handling..."
      missing_file = test_dir.join("nonexistent_file.txt")
      scanner = ImageVirusScanner.new(missing_file.to_s)

      begin
        scanner.call
        puts "   ✗ Should have raised error for missing file"
      rescue => e
        puts "   ✓ Error handling works: #{e.class.name}"
      end

      puts "\n" + "=" * 70
      puts "VIRUS SCAN TEST COMPLETE"
      puts "=" * 70
      puts "\nNOTE: EICAR is a harmless test file used to verify antivirus software."
      puts "It contains NO actual malicious code."
      puts "Learn more: https://www.eicar.org/\n\n"

    ensure
      # Cleanup test files
      puts "\nCleaning up test files..."
      FileUtils.rm_rf(test_dir)
      puts "Test files removed."
    end
  end

  desc "Create EICAR test file for manual testing"
  task create_eicar: :environment do
    test_dir = Rails.root.join("tmp", "virus_scan_test")
    FileUtils.mkdir_p(test_dir)

    eicar_file = test_dir.join("eicar_test.txt")
    eicar_string = 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
    File.write(eicar_file, eicar_string)

    puts "EICAR test file created at: #{eicar_file}"
    puts "This file should be detected as a virus by ClamAV."
    puts "\nTest it with:"
    puts "  clamscan #{eicar_file}"
    puts "\nOr in Rails console:"
    puts "  ImageVirusScanner.new('#{eicar_file}').call"
    puts "\nIMPORTANT: This is NOT a real virus. It's a standard antivirus test file."
  end
end
