function animateValue(id, start, end, duration) {
    let obj = document.getElementById(id);
    let startTime = performance.now();
    function update() {
        let elapsed = Math.min(performance.now() - startTime, duration);
        obj.textContent = Math.round(start + (end - start) * (elapsed / duration)).toString();
        if (elapsed < duration) requestAnimationFrame(update);
    }
    requestAnimationFrame(update);
}

function animatePercentageValue(id, start, end, duration) {
    let obj = document.getElementById(id);
    let startTime = performance.now();
    function update() {
        let elapsed = Math.min(performance.now() - startTime, duration);
        let currentValue = start + (end - start) * (elapsed / duration);
        obj.textContent = currentValue.toFixed(2) + '%';
        if (elapsed < duration) requestAnimationFrame(update);
    }
    requestAnimationFrame(update);
}
