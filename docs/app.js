(function () {
    "use strict";

    var root = document.documentElement;
    var toggle = document.getElementById("theme-toggle");

    function currentTheme() {
        return root.dataset.theme === "dark" ? "dark" : "light";
    }

    function applyTheme(theme) {
        root.dataset.theme = theme;
        root.style.colorScheme = theme;
        try {
            localStorage.setItem("theme", theme);
        } catch (e) {
        }
        if (toggle) {
            toggle.setAttribute("aria-label", theme === "dark" ? "Switch to light theme" : "Switch to dark theme");
        }
    }

    applyTheme(currentTheme());

    if (toggle) {
        toggle.addEventListener("click", function () {
            applyTheme(currentTheme() === "dark" ? "light" : "dark");
        });
    }

    function fallbackCopy(text, done) {
        var area = document.createElement("textarea");
        area.value = text;
        area.setAttribute("readonly", "");
        area.style.position = "fixed";
        area.style.opacity = "0";
        document.body.appendChild(area);
        area.select();
        try {
            document.execCommand("copy");
            done();
        } catch (e) {
        }
        document.body.removeChild(area);
    }

    Array.prototype.forEach.call(document.querySelectorAll(".copy-button"), function (button) {
        button.addEventListener("click", function () {
            var code = document.getElementById(button.dataset.copy);
            if (!code) {
                return;
            }
            var text = code.textContent.trim();
            var done = function () {
                button.classList.add("copied");
                button.textContent = "Copied";
                window.setTimeout(function () {
                    button.classList.remove("copied");
                    button.textContent = "Copy";
                }, 1600);
            };
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(text).then(done, function () {
                    fallbackCopy(text, done);
                });
            } else {
                fallbackCopy(text, done);
            }
        });
    });

    var year = document.getElementById("year");
    if (year) {
        year.textContent = String(new Date().getFullYear());
    }

    var links = Array.prototype.slice.call(document.querySelectorAll(".nav a[href^='#']"));
    var sections = [];
    links.forEach(function (link) {
        var section = document.querySelector(link.getAttribute("href"));
        if (section) {
            sections.push(section);
        }
    });

    if ("IntersectionObserver" in window && sections.length) {
        var observer = new IntersectionObserver(function (entries) {
            entries.forEach(function (entry) {
                if (!entry.isIntersecting) {
                    return;
                }
                links.forEach(function (link) {
                    link.classList.toggle("active", link.getAttribute("href") === "#" + entry.target.id);
                });
            });
        }, { rootMargin: "-45% 0px -50% 0px", threshold: 0 });
        sections.forEach(function (section) {
            observer.observe(section);
        });
    }
})();
