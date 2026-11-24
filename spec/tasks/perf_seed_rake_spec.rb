require "rails_helper"
require "rake"

RSpec.describe "rake perf:seed" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  let(:task) { Rake::Task["perf:seed"] }

  def run_task
    task.invoke
  ensure
    task.reenable
  end

  it "crea los movimientos y la segunda vez no hace nada" do
    stub_const("PerformanceSeed::BATCH_SIZE", 1_000)
    allow(PerformanceSeed).to receive(:new).and_wrap_original { |original| original.call(total: 300) }

    expect { run_task }.to output(/300 movimientos en el hogar "Rendimiento"/).to_stdout
    expect { run_task }.to output(/ya tiene movimientos; nada que hacer/).to_stdout
    expect(Transaction.count).to eq(300)
  end

  it "en producción aborta antes de tocar la BD" do
    allow(Rails.env).to receive(:production?).and_return(true)
    expect(PerformanceSeed).not_to receive(:new)

    expect { run_task }.to raise_error(SystemExit).and output(/no se ejecuta en producción/).to_stderr
    expect(User.count).to eq(0)
  end
end
