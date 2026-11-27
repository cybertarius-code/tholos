require "rails_helper"

# Recibo adjunto a un movimiento (US-0107)
RSpec.describe Transaction, "recibo" do
  let(:transaction) { create(:transaction) }

  def attach(name, content_type: nil)
    transaction.receipt = Rack::Test::UploadedFile.new(file_fixture(name), content_type)
  end

  it "admite una foto y un PDF" do
    attach("recibo.jpg")
    expect(transaction.save).to be(true)
    expect(described_class.with_attached_receipt.find(transaction.id)).to be_receipt_image

    attach("factura.pdf")
    expect(transaction.save).to be(true)
    expect(described_class.with_attached_receipt.find(transaction.id)).not_to be_receipt_image
  end

  it "rechaza otro tipo por su contenido, aunque se declare como imagen" do
    attach("recibos.zip", content_type: "image/jpeg")

    expect(transaction.save).to be(false)
    expect(transaction.errors.of_kind?(:receipt, :content_type)).to be(true)
    expect(ActiveStorage::Blob.count).to eq(0)
  end

  it "rechaza un fichero de más de 10 MB" do
    attach("recibo.jpg")
    transaction.attachment_changes["receipt"].attachment.blob.byte_size = 10.megabytes + 1

    expect(transaction.save).to be(false)
    expect(transaction.errors.of_kind?(:receipt, :too_large)).to be(true)
  end

  it "la miniatura es de 200 px como mucho" do
    attach("recibo.jpg")
    transaction.save!
    thumb = described_class.with_attached_receipt.find(transaction.id).receipt.variant(:thumb).processed

    expect(thumb.image.blob.tap(&:analyze).metadata).to include("width" => 200, "height" => 150)
  end
end
