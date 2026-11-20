require "rails_helper"
require "rake"

RSpec.describe "rake categories:seed_defaults" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  let(:task) { Rake::Task["categories:seed_defaults"] }
  let(:household) { create(:household, name: "Casa") }

  before { task.reenable }

  def run_task(*args)
    task.invoke(*args)
  ensure
    task.reenable
  end

  it "crea las categorías por defecto y es idempotente" do
    expect { run_task(household.id.to_s) }.to output(/23 categorías/).to_stdout
    expect { run_task(household.id.to_s) }.to output(/0 categorías/).to_stdout
    expect(household.categories.count).to eq(23)
  end

  it "falla con un hogar inexistente" do
    expect { run_task("0") }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "aborta sin ID" do
    expect { run_task }.to raise_error(SystemExit).and output(/Falta el ID/).to_stderr
  end
end
