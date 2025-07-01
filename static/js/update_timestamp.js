function timeAgo(date) {
    const seconds = Math.floor((Date.now() - date.getTime()) / 1000);
    const rtf = new Intl.RelativeTimeFormat(navigator.language, { numeric: "auto" });

    const intervals = [
        { limit: 60, divisor: 1, unit: "second" },
        { limit: 3600, divisor: 60, unit: "minute" },
        { limit: 86400, divisor: 3600, unit: "hour" },
        { limit: 604800, divisor: 86400, unit: "day" },
        { limit: 2592000, divisor: 604800, unit: "week" },
        { limit: 31536000, divisor: 2592000, unit: "month" },
        { limit: Infinity, divisor: 31536000, unit: "year" }
    ];

    for (const { limit, divisor, unit } of intervals) {
        if (seconds < limit) {
            const value = Math.floor(seconds / divisor);
            return rtf.format(-value, unit);
        }
    }
}

function updateTimestamps() {
    const elements = document.querySelectorAll("[data-timestamp]");
    elements.forEach(el => {
        const ts = Number(el.dataset.timestamp);
        const date = new Date(ts);

        const rel = el.querySelector(".timestamp-rel");
        const fixed = el.querySelector(".timestamp-fixed");

        if (rel) rel.textContent = timeAgo(date);
        if (fixed) fixed.textContent = date.toLocaleString();
    });
}

updateTimestamps();
setInterval(updateTimestamps, 1000);
