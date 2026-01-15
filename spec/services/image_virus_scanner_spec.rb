require 'rails_helper'

RSpec.describe ImageVirusScanner, type: :model do
  let(:file_path) { '/tmp/fake.png' }

  it 'returns true when scan passes' do
    scanner = ImageVirusScanner.new(file_path)
    allow(scanner).to receive(:call).and_return(true)
    expect(scanner.call).to be true
  end

  it 'raises VirusDetectedError when scan fails' do
    scanner = ImageVirusScanner.new(file_path)
    allow(scanner).to receive(:call).and_raise(ImageVirusScanner::VirusDetectedError.new('Virus!'))
    expect { scanner.call }.to raise_error(ImageVirusScanner::VirusDetectedError)
  end

  it 'raises ScanFailedError when scan service errors' do
    scanner = ImageVirusScanner.new(file_path)
    allow(scanner).to receive(:call).and_raise(ImageVirusScanner::ScanFailedError.new('Scan failed!'))
    expect { scanner.call }.to raise_error(ImageVirusScanner::ScanFailedError)
  end
end
