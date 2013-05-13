class MailPreview < MailView

  def notify_system_admin
    system_admin = User.current.first
    user = User.current.first
    UserMailer.notify_system_admin(system_admin, user)
  end

  def status_activated
    user = User.current.first
    UserMailer.status_activated(user)
  end

  def invite_user_to_site
    site_user = SiteUser.first
    UserMailer.invite_user_to_site(site_user)
  end

  def user_added_to_project
    project_user = ProjectUser.first
    UserMailer.user_added_to_project(project_user)
  end

  def invite_user_to_project
    project_user = ProjectUser.first
    UserMailer.invite_user_to_project(project_user)
  end

  def sheet_completion_request
    sheet = Sheet.current.first
    email = "bcc@example.com"
    UserMailer.sheet_completion_request(sheet, email, "Additional Text")
  end

  def survey_completed
    sheet = Sheet.current.first
    UserMailer.survey_completed(sheet)
  end

  def survey_user_link
    sheet = Sheet.current.first
    UserMailer.survey_user_link(sheet)
  end

  def export_ready
    export = Export.current.first
    UserMailer.export_ready(export)
  end

  def daily_digest
    recipient = User.current.first
    UserMailer.daily_digest(recipient)
  end

  def comment_by_mail
    comment = Comment.current.first
    recipient = User.current.first
    UserMailer.comment_by_mail(comment, recipient)
  end

  def project_news
    post = Post.current.first
    recipient = User.current.first
    UserMailer.project_news(post, recipient)
  end
end
