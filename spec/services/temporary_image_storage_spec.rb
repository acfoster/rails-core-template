require 'rails_helper'

RSpec.describe TemporaryImageStorage, type: :model do
  let(:uploaded_file) { Rack::Test::UploadedFile.new(StringIO.new('fake'), 'image/png', original_filename: 'chart.png') }
  let(:storage) { TemporaryImageStorage.new(uploaded_file) }

  it 'stores image and returns path' do
    allow(storage).to receive(:store).and_return({ path: '/tmp/fake.png' })
    result = storage.store
    expect(result[:path]).to eq('/tmp/fake.png')
  end

  it 'cleans up image after processing' do
    allow(storage).to receive(:cleanup!).and_return(true)
    expect(storage.cleanup!).to be true
  end

  it 'raises InvalidImageError for invalid file' do
    allow(storage).to receive(:store).and_raise(TemporaryImageStorage::InvalidImageError.new('Invalid!'))
    expect { storage.store }.to raise_error(TemporaryImageStorage::InvalidImageError)
  end
end
