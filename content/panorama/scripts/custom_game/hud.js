/**
 * 数码守护者 HUD 脚本
 * hud.js — P7 阶段完整实现
 */

"use strict";

(function () {

    // 面板引用
    var labelWave   = $("#LabelWave");
    var labelLives  = $("#LabelLives");
    var labelShards = $("#LabelShards");

    /**
     * 更新波次显示
     * @param {number} current 当前波次
     * @param {number} total   总波次
     */
    function UpdateWave(current, total) {
        if (labelWave) {
            labelWave.text = current + " / " + total;
        }
    }

    /**
     * 更新生命值显示
     * @param {number} lives 剩余生命值
     */
    function UpdateLives(lives) {
        if (labelLives) {
            labelLives.text = String(lives);
            // 生命值低时变红
            labelLives.SetHasClass("lives-critical", lives <= 3);
        }
    }

    /**
     * 更新数据碎片显示
     * @param {number} shards 当前碎片数量
     */
    function UpdateShards(shards) {
        if (labelShards) {
            labelShards.text = String(shards);
        }
    }

    // 监听自定义网络表更新（P5/P7 阶段接入）
    // GameEvents.Subscribe("digimon_td_state_update", function(data) {
    //     UpdateWave(data.wave, 40);
    //     UpdateLives(data.lives);
    //     UpdateShards(data.shards);
    // });

    // 初始化默认显示
    UpdateWave(0, 40);
    UpdateLives(10);
    UpdateShards(0);

}());
