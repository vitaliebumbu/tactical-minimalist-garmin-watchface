import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Weather;

class CasioMaxView extends WatchUi.WatchFace {

    private const BG       = 0x000000;
    private const PANEL_BG = 0x0E0F11;
    private const PANEL_ED = 0x3A3D38;
    private const ON       = 0xDFE7DA;
    private const DIM      = 0x1E2019;
    private const LABEL    = 0x7A7E77;
    private const AOD_ON   = 0x5A8A4A;
    private const AOD_DIM  = 0x1E2E18;

    // a b c d e f g
    private var _s = [
        [1,1,1,1,1,1,0],[0,1,1,0,0,0,0],[1,1,0,1,1,0,1],[1,1,1,1,0,0,1],
        [0,1,1,0,0,1,1],[1,0,1,1,0,1,1],[1,0,1,1,1,1,1],[1,1,1,0,0,0,0],
        [1,1,1,1,1,1,1],[1,1,1,1,0,1,1]
    ];

    private var _cx = 227;
    private var _cy = 227;
    private var _isAwake = true;

    function initialize() { WatchFace.initialize(); }
    function onLayout(dc as Dc) as Void { _cx = dc.getWidth()/2; _cy = dc.getHeight()/2; }
    function onShow() as Void {}
    function onHide() as Void {}
    function onUpdate(dc as Dc) as Void { if(_isAwake){drawActive(dc);}else{drawAod(dc);} }
    function onExitSleep() as Void { _isAwake=true; WatchUi.requestUpdate(); }
    function onEnterSleep() as Void { _isAwake=false; WatchUi.requestUpdate(); }

    // ═══════════════════════════════════════════════════════════
    private function drawActive(dc) {
        dc.setColor(Graphics.COLOR_TRANSPARENT, BG);
        dc.clear();

        var ct = System.getClockTime();
        var info = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var days = ["SUN","MON","TUE","WED","THU","FRI","SAT"];
        var day = days[info.day_of_week - 1];
        var dateStr = info.day.format("%d") + "-" + info.month.format("%d");

        // ── Battery (top center) ───────────────────────────────
        drawBat(dc, 34);

        // ── Radar (top-left) ────────────────────────────────────
        drawRadar(dc, 130, 108, 48, ct.sec);

        // ── Health stack (top-right): HR, STR, TMP ─────────────
        panel(dc, 255, 58, 120, 90);
        var px = 264;
        var pvx = 366;
        var py = 62;
        var pdy = 26;

        // Heart rate
        var hrVal = 0;
        var hrHist = ActivityMonitor.getHeartRateHistory(1, true);
        if (hrHist != null) {
            var hrSample = hrHist.next();
            if (hrSample != null && hrSample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                hrVal = hrSample.heartRate;
            }
            System.println("HR: " + hrVal);
        } else {
            System.println("HR: history null");
        }
        dc.setColor(ON, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(px, py+12, 5);
        dc.fillCircle(px+8, py+12, 5);
        dc.fillPolygon([[px-5, py+15], [px+13, py+15], [px+4, py+24]]);
        dc.drawText(pvx, py+12, Graphics.FONT_XTINY, hrVal > 0 ? hrVal.format("%d") : "--",
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Stress
        var stress = 0;
        var stressIter = SensorHistory.getStressHistory({:period => 3600, :order => SensorHistory.ORDER_NEWEST_FIRST});
        if (stressIter != null) {
            var stressSample = stressIter.next();
            if (stressSample != null) {
                System.println("STR sample data: " + stressSample.data);
                if (stressSample.data != null) {
                    stress = stressSample.data.toNumber();
                }
            } else {
                System.println("STR: no sample in iterator");
            }
        } else {
            System.println("STR: getStressHistory returned null");
        }
        dc.setColor(LABEL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(px, py+pdy+2, Graphics.FONT_XTINY, "STR", Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(ON, Graphics.COLOR_TRANSPARENT);
        dc.drawText(pvx, py+pdy+2, Graphics.FONT_XTINY, stress > 0 ? stress.format("%d") : "--", Graphics.TEXT_JUSTIFY_RIGHT);

        // Temperature (Fahrenheit)
        var tempStr = "--";
        var conditions = Weather.getCurrentConditions();
        if (conditions != null && conditions.temperature != null) {
            var tempF = (conditions.temperature * 9 / 5 + 32).toNumber();
            tempStr = tempF.format("%d") + "°F";
            System.println("TMP: " + conditions.temperature + "C -> " + tempF + "F");
        } else {
            System.println("TMP: conditions=" + conditions);
        }
        dc.setColor(LABEL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(px, py+pdy*2+2, Graphics.FONT_XTINY, "T", Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(ON, Graphics.COLOR_TRANSPARENT);
        dc.drawText(pvx, py+pdy*2+2, Graphics.FONT_XTINY, tempStr, Graphics.TEXT_JUSTIFY_RIGHT);

        // ── Main time HH:MM:ss (perfectly centered) ──────────
        var dw = 58;
        var dh = 98;
        var cw = 18;
        var gap = 5;
        var sw = 29;
        var sh = 48;
        var secGap = 6;
        // Total width: 4 digits + colon + 4 gaps + secGap + 2 sec digits + sec gap
        var totalW = 4*dw + cw + 4*gap + secGap + 2*sw + 3;
        var mx = _cx - totalW/2;
        var my = _cy - dh/2;

        dig(dc, mx, my, ct.hour/10, dw, dh, ON, DIM); mx += dw+gap;
        dig(dc, mx, my, ct.hour%10, dw, dh, ON, DIM); mx += dw+gap;
        drawColon(dc, mx, my, cw, dh, ON); mx += cw+gap;
        dig(dc, mx, my, ct.min/10, dw, dh, ON, DIM); mx += dw+gap;
        dig(dc, mx, my, ct.min%10, dw, dh, ON, DIM);

        // Seconds (smaller, bottom-aligned with main digits)
        mx += dw + secGap;
        dig(dc, mx, my+dh-sh, ct.sec/10, sw, sh, ON, DIM);
        mx += sw + 3;
        dig(dc, mx, my+dh-sh, ct.sec%10, sw, sh, ON, DIM);

        // ── Date strip (below time) ───────────────────────────
        var sy = my + dh + 10;
        var stripW = 154;
        var stripH = 32;
        var stripX = _cx - stripW/2;
        panel(dc, stripX, sy, stripW, stripH);
        dc.setColor(ON, Graphics.COLOR_TRANSPARENT);
        dc.drawText(stripX + stripW/4, sy + stripH/2, Graphics.FONT_XTINY, day,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(PANEL_ED, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_cx, sy+5, _cx, sy+stripH-5);
        dc.setColor(ON, Graphics.COLOR_TRANSPARENT);
        dc.drawText(stripX + 3*stripW/4, sy + stripH/2, Graphics.FONT_XTINY, dateStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ── Steps ──────────────────────────────────────────────
        var stepsInfo = ActivityMonitor.getInfo();
        var steps = (stepsInfo != null && stepsInfo.steps != null) ? stepsInfo.steps : 0;
        var stepStr = steps.format("%d");
        if (steps >= 1000) {
            var slen = stepStr.length();
            stepStr = stepStr.substring(0, slen-3) + "," + stepStr.substring(slen-3, slen);
        }
        var dataY = sy + stripH + 8;
        dc.setColor(LABEL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx - 30, dataY, Graphics.FONT_XTINY, "STEPS", Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(ON, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + 30, dataY, Graphics.FONT_XTINY, stepStr, Graphics.TEXT_JUSTIFY_LEFT);

        // ── Calories (same style as steps) ─────────────────────
        var actInfo = ActivityMonitor.getInfo();
        var cal = (actInfo != null && actInfo.calories != null) ? actInfo.calories : 0;
        var calStr = cal.format("%d");
        if (cal >= 1000) {
            var clen = calStr.length();
            calStr = calStr.substring(0, clen-3) + "," + calStr.substring(clen-3, clen);
        }
        dc.setColor(LABEL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx - 30, dataY + 26, Graphics.FONT_XTINY, "CAL", Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(ON, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + 30, dataY + 26, Graphics.FONT_XTINY, calStr, Graphics.TEXT_JUSTIFY_LEFT);

        // ── TACTICAL brand (bottom) ───────────────────────────
        dc.setColor(LABEL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, 400, Graphics.FONT_XTINY, "TACTICAL", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ═══════════════════════════════════════════════════════════
    private function drawAod(dc) {
        dc.setColor(Graphics.COLOR_TRANSPARENT, BG); dc.clear();
        var ct = System.getClockTime();
        var info = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var days = ["SUN","MON","TUE","WED","THU","FRI","SAT"];
        var day = days[info.day_of_week - 1];
        var dateStr = info.day.format("%d") + "-" + info.month.format("%d");

        // ── Main time HH:MM:ss (perfectly centered, same as active) ──
        var dw = 58;
        var dh = 98;
        var cw = 18;
        var gap = 5;
        var sw = 29;
        var sh = 48;
        var secGap = 6;
        var totalW = 4*dw + cw + 4*gap + secGap + 2*sw + 3;
        var mx = _cx - totalW/2;
        var my = _cy - dh/2;

        dig(dc, mx, my, ct.hour/10, dw, dh, AOD_ON, AOD_DIM); mx += dw+gap;
        dig(dc, mx, my, ct.hour%10, dw, dh, AOD_ON, AOD_DIM); mx += dw+gap;
        drawColon(dc, mx, my, cw, dh, AOD_ON); mx += cw+gap;
        dig(dc, mx, my, ct.min/10, dw, dh, AOD_ON, AOD_DIM); mx += dw+gap;
        dig(dc, mx, my, ct.min%10, dw, dh, AOD_ON, AOD_DIM);

        mx += dw + secGap;
        dig(dc, mx, my+dh-sh, ct.sec/10, sw, sh, AOD_ON, AOD_DIM);
        mx += sw + 3;
        dig(dc, mx, my+dh-sh, ct.sec%10, sw, sh, AOD_ON, AOD_DIM);

        // ── Date strip (below time) ─────────────────────────────
        var stripW = 154;
        var stripH = 32;
        var stripX = _cx - stripW/2;
        var sy = my + dh + 8;
        dc.setColor(AOD_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(stripX, sy, stripW, stripH, 4);
        dc.setColor(AOD_ON, Graphics.COLOR_TRANSPARENT);
        dc.drawText(stripX + stripW/4, sy + stripH/2, Graphics.FONT_XTINY, day,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(AOD_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_cx, sy+5, _cx, sy+stripH-5);
        dc.setColor(AOD_ON, Graphics.COLOR_TRANSPARENT);
        dc.drawText(stripX + 3*stripW/4, sy + stripH/2, Graphics.FONT_XTINY, dateStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ═══════════════════════════════════════════════════════════
    // 7-SEGMENT DIGIT
    // ═══════════════════════════════════════════════════════════
    private function dig(dc, x, y, d, w, h, on, dim) {
        if (d < 0 || d > 9) { return; }
        var sg = _s[d];
        var t = (w * 0.22).toNumber();  // bolder segments
        if (t < 4) { t = 4; }
        var ht = t / 2;
        var p = 2;  // gap at corners
        var mid = y + h / 2;

        // Horizontal segment params
        var hL = x + t + p;          // left edge
        var hR = x + w - t - p;      // right edge

        // Vertical segment params
        var vTop = y + t + p;
        var vMid = mid;
        var vBot = y + h - t - p;

        // Draw all 7 as ghost, then active on top
        // a: top horizontal
        hSeg(dc, hL, hR, y + ht, ht, dim);
        if(sg[0]==1){ hSeg(dc, hL, hR, y + ht, ht, on); }
        // d: bottom horizontal
        hSeg(dc, hL, hR, y + h - ht, ht, dim);
        if(sg[3]==1){ hSeg(dc, hL, hR, y + h - ht, ht, on); }
        // g: middle horizontal
        hSeg(dc, hL, hR, mid, ht, dim);
        if(sg[6]==1){ hSeg(dc, hL, hR, mid, ht, on); }
        // f: top-left vertical
        vSeg(dc, x + ht, vTop, vMid - p, ht, dim);
        if(sg[5]==1){ vSeg(dc, x + ht, vTop, vMid - p, ht, on); }
        // b: top-right vertical
        vSeg(dc, x + w - ht, vTop, vMid - p, ht, dim);
        if(sg[1]==1){ vSeg(dc, x + w - ht, vTop, vMid - p, ht, on); }
        // e: bottom-left vertical
        vSeg(dc, x + ht, vMid + p, vBot, ht, dim);
        if(sg[4]==1){ vSeg(dc, x + ht, vMid + p, vBot, ht, on); }
        // c: bottom-right vertical
        vSeg(dc, x + w - ht, vMid + p, vBot, ht, dim);
        if(sg[2]==1){ vSeg(dc, x + w - ht, vMid + p, vBot, ht, on); }
    }

    // Horizontal tapered segment: pointed left & right ends
    private function hSeg(dc, left, right, cy, ht, c) {
        var tp = ht * 0.6;
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [left,      cy],           // left point
            [left+tp,   cy-ht],        // top-left
            [right-tp,  cy-ht],        // top-right
            [right,     cy],           // right point
            [right-tp,  cy+ht],        // bottom-right
            [left+tp,   cy+ht]         // bottom-left
        ]);
    }

    // Vertical tapered segment: pointed top & bottom ends
    private function vSeg(dc, cx, top, bot, ht, c) {
        var tp = ht * 0.6;
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [cx,      top],            // top point
            [cx+ht,   top+tp],         // top-right
            [cx+ht,   bot-tp],         // bottom-right
            [cx,      bot],            // bottom point
            [cx-ht,   bot-tp],         // bottom-left
            [cx-ht,   top+tp]          // top-left
        ]);
    }

    private function drawColon(dc, x, y, w, h, c) {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        var d = 5;
        var cx = x + w/2 - d/2;
        dc.fillRectangle(cx, y + h/3 - d/2, d, d);
        dc.fillRectangle(cx, y + 2*h/3 - d/2, d, d);
    }

    // ═══════════════════════════════════════════════════════════
    // RADAR
    // ═══════════════════════════════════════════════════════════
    private function drawRadar(dc, cx, cy, r, sec) {
        dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawCircle(cx, cy, r);
        // Crosshair
        var c = r*8/10;
        dc.drawLine(cx, cy-c, cx, cy+c);
        dc.drawLine(cx-c, cy, cx+c, cy);
        // Ticks
        for (var i=0; i<60; i++) {
            var a = (i*6-90)*Math.PI/180.0;
            var co = Math.cos(a); var si = Math.sin(a);
            var maj = (i%5)==0;
            dc.setColor(maj ? ON : DIM, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(maj ? 2 : 1);
            dc.drawLine(cx+(r-2)*co, cy+(r-2)*si, cx+(maj?r-10:r-5)*co, cy+(maj?r-10:r-5)*si);
        }
        dc.setPenWidth(1);
        // Hub
        dc.setColor(ON, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 4);
        dc.setColor(BG, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 2);
        // Hand
        var a = (sec*6-90)*Math.PI/180.0;
        dc.setColor(ON, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(cx, cy, cx+Math.cos(a)*r*55/100, cy+Math.sin(a)*r*55/100);
        dc.setPenWidth(1);
    }

    // ═══════════════════════════════════════════════════════════
    // PANEL
    // ═══════════════════════════════════════════════════════════
    private function panel(dc, x, y, w, h) {
        dc.setColor(PANEL_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, 4);
        dc.setColor(PANEL_ED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(x, y, w, h, 4);
    }

    // ═══════════════════════════════════════════════════════════
    // BATTERY
    // ═══════════════════════════════════════════════════════════
    private function drawBat(dc, y) {
        var bat = System.getSystemStats().battery.toNumber();
        var batText = bat.format("%d") + "%";
        // Battery icon sits to the left of the percentage, both centered as a group
        var bw = 24;
        var bh = 12;
        var iconGap = 6;
        // Total group width ≈ icon(24+3) + gap + text(~30)
        var groupW = bw + 3 + iconGap + 30;
        var gx = _cx - groupW / 2;
        // Icon
        dc.setColor(ON, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(gx, y, bw, bh, 2);
        dc.fillRectangle(gx + bw, y + 3, 3, 6);
        var fillW = ((bw - 4) * bat / 100).toNumber();
        if (fillW > 0) {
            dc.fillRectangle(gx + 2, y + 2, fillW, bh - 4);
        }
        // Percentage text right of icon, vertically centered to icon
        dc.drawText(gx + bw + 3 + iconGap, y + bh/2, Graphics.FONT_XTINY, batText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
