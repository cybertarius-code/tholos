import * as echarts from "echarts/core"
import { LineChart, BarChart, PieChart } from "echarts/charts"
import { GridComponent, TooltipComponent, AriaComponent, LegendComponent, DatasetComponent } from "echarts/components"
import { CanvasRenderer } from "echarts/renderers"
echarts.use([LineChart, BarChart, PieChart, GridComponent, TooltipComponent, AriaComponent, LegendComponent, DatasetComponent, CanvasRenderer])
export default echarts
