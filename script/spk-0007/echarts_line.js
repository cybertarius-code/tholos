import * as echarts from "echarts/core"
import { LineChart } from "echarts/charts"
import { GridComponent, TooltipComponent, AriaComponent } from "echarts/components"
import { CanvasRenderer } from "echarts/renderers"
echarts.use([LineChart, GridComponent, TooltipComponent, AriaComponent, CanvasRenderer])
export default echarts
