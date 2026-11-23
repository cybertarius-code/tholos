# SPK-0007 (prototipo, solo desarrollo): saldo de 90 días con ECharts o Chart.js.
# No es producto: la ruta solo existe en desarrollo y la rama no se mezcla.
class SpikeChartsController < ApplicationController
  DAYS = 90

  def show
    @library = params[:lib].presence_in(%w[ echarts chartjs none ]) || "echarts"
    @account = Current.household.accounts.ordered.first
    @series = @account ? daily_balances(@account) : []
  end

  private
    # Saldo conciliado al cierre de cada día: una consulta para el punto de
    # partida y otra con los movimientos del periodo
    def daily_balances(account)
      from = Date.current - (DAYS - 1)
      balance = account.balance_cents(on: from - 1)
      sums = account.transactions.cleared.where(date: from..Date.current).group(:date).sum(:amount_cents)

      (from..Date.current).map do |date|
        balance += sums.fetch(date, 0)
        [ date.iso8601, balance ]
      end
    end
end
