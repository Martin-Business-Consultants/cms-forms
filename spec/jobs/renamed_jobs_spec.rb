# frozen_string_literal: true

require "rails_helper"

# Jobs renamed to the _later/_now pattern keep their old class for one release,
# so a job already queued under the old name still runs. Remove with them.
RSpec.describe "Renamed jobs" do
  it "still runs NotifyFormSubmissionJob as FormSubmission::NotificationJob" do
    expect(NotifyFormSubmissionJob.superclass).to eq(FormSubmission::NotificationJob)
  end
end
