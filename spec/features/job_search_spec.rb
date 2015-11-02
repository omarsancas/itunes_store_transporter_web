# coding: utf-8
require "spec_helper"

feature "Job search", :js do
  it "finds job in the selected state" do
    found = create(:upload_job)
    found.running!

    not_found = create(:upload_job)
    not_found.success!

    visit app.url(:jobs)

    search { select "Running", :from => "State" }

    expect(page).to have_text("Search: state Running")
    expect(page).to have_selector(".job", :text => "Running", :count => 1)
    expect(page).to have_no_selector(".job", :text => "Queued")
  end

  it "finds jobs of the selected type" do
    found = create(:upload_job)
    not_found = create(:lookup_job)

    visit app.url(:jobs)

    search { select "Upload", :from => "Type" }

    expect(page).to have_text("Search: type Upload")
    expect(page).to have_selector(".job", :text => "Upload", :count => 1)
    expect(page).to have_no_selector(".job", :text => "Lookup")
  end

  it "finds jobs with the selected priority" do
    found = create(:upload_job, :priority => :high)
    not_found = create(:upload_job, :priority => :normal)

    visit app.url(:jobs)

    search { select "High", :from => "Priority" }

    expect(page).to have_text("Search: priority High")
    expect(page).to have_selector(".job", :text => "High", :count => 1)
    expect(page).to have_no_selector(".job", :text => "Normal")
  end

  it "finds jobs with the given target" do
    found = create(:status_job)
    not_found = create(:status_job)

    visit app.url(:jobs)

    search { fill_in "Target", :with => found.target }

    expect(page).to have_text(%{Search: target "#{found.target}"})
    expect(page).to have_selector(".job", :text => found.target, :count => 1)
    expect(page).to have_no_selector(".job", :text => not_found.target)
  end

  it "finds jobs for the given account" do
    found = create(:status_job).account
    not_found = create(:status_job).account

    visit app.url(:jobs)

    search { select found.username, :from => "Account" }

    expect(page).to have_text(%{Search: account "#{found.username}"})
    expect(page).to have_selector(".job", :text => found.username, :count => 1)
    expect(page).to have_no_selector(".job", :text => not_found.username)
  end

  describe "searching by date" do
    before do
      @start_date = 10.days.ago
      @end_date = @start_date + 2.days

      @found = [ create(:status_job),  create(:status_job) ]
      @found[0].update_column(:updated_at, @start_date)
      @found[1].update_column(:updated_at, @end_date)

      @not_found = create(:lookup_job)

      visit app.url(:jobs)
    end

    context "selecting dates from the calendar" do
      it "finds jobs updated between the given date range" do
        search do
          pick_date("_updated_at_from", @start_date)
          pick_date("_updated_at_to", @end_date)
        end

        expect(page).to have_text("Search: updated #{@start_date.strftime("%m/%d/%Y")} to #{@end_date.strftime("%m/%d/%Y")}")
        expect(page).to have_selector(".job", :text => @found[0].type, :count => 2)
        expect(page).to have_no_selector(".job", :text => @not_found.type)
      end

      it "finds jobs updated on the given date", :pending => "Single date search broken, GitHub issue #5" do
        search { pick_date("_updated_at_from", @start_date) }

        expect(page).to have_text("Search: updated #{@start_date.strftime("%m/%d/%Y")} to #{@end_date.strftime("%m/%d/%Y")}")
        expect(page).to have_selector(".job", :text => @found[0].type, :count => 2)
        expect(page).to have_no_selector(".job", :text => @not_found.type)
      end
    end

    context "entering dates" do
      it "finds jobs updated on the given date", :pending => "Single date search broken, GitHub issue #5" do
        search { fill_in "_updated_at_from", :with => @start_date.strftime("%D") }

        expect(page).to have_text("Search: updated #{@start_date.strftime("%D")}")
        expect(page).to have_selector(".job", :text => @found[0].type, :count => 1)
        expect(page).to have_no_selector(".job", :text => @not_found.type)
      end

      it "finds jobs updated between the given date range" do
        search do
          fill_in "_updated_at_from", :with => @start_date.strftime("%D")
          fill_in "_updated_at_to", :with => @end_date.strftime("%D")
        end

        expect(page).to have_text("Search: updated #{@start_date.strftime("%D")} to #{@end_date.strftime("%D")}")
        expect(page).to have_selector(".job", :text => @found[0].type, :count => 2)
        expect(page).to have_no_selector(".job", :text => @not_found.type)
      end
    end
  end


  # first click is asc, next is desc
  describe "sorting the results" do
    before { @jobs = [ create(:status_job), create(:upload_job) ] }

    it "sorts by state" do
      @jobs[0].queued!
      @jobs[1].success!

      visit app.url(:search)

      click_on "State"
      order = all(".jobs table tbody tr")

      expect(page).to have_text("↑")
      expect(order[0].text).to have_text(@jobs[0].state)
      expect(order[1].text).to have_text(@jobs[1].state)

      click_on "State"
      order = all(".jobs table tbody tr")

      expect(page).to have_text("↓")
      expect(order[0].text).to have_text(@jobs[1].state)
      expect(order[1].text).to have_text(@jobs[0].state)
    end

    it "sorts by type" do
      visit app.url(:search)

      click_on "Type"
      order = all(".jobs table tbody tr")

      expect(page).to have_text("↑")
      expect(order[0].text).to have_text(@jobs[0].type)
      expect(order[1].text).to have_text(@jobs[1].type)

      click_on "Type"
      order = all(".jobs table tbody tr")

      expect(page).to have_text("↓")
      expect(order[0].text).to have_text(@jobs[1].type)
      expect(order[1].text).to have_text(@jobs[0].type)
    end
  end

  def search
    click_link "Search"
    yield
    click_button "Search"
  end

  def pick_date(field, date)
    find_field(field).trigger("focus")
    find(".ui-datepicker-month").select(date.strftime("%b"))
    find(".ui-datepicker-year").select(date.year)
    click_on date.day
  end
end