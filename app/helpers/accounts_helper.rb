module AccountsHelper
  def account_kind_options
    Account::KINDS.map { |kind| [ t("accounts.kinds.#{kind}"), kind ] }
  end

  def account_kind_label(account)
    t("accounts.kinds.#{account.kind}")
  end

  def account_classification_label(account)
    t("accounts.classifications.#{account.classification}")
  end

  def account_opening_amount_label(liability)
    liability ? t("accounts.form.opening_debt") : t("accounts.form.opening_balance")
  end
end
