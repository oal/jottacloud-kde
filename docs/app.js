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

    var tabs = Array.prototype.slice.call(document.querySelectorAll(".gallery-tab"));
    var panes = Array.prototype.slice.call(document.querySelectorAll(".gallery-pane"));

    function selectTab(tab, focus) {
        tabs.forEach(function (item) {
            var active = item === tab;
            item.classList.toggle("is-active", active);
            item.setAttribute("aria-selected", active ? "true" : "false");
            item.tabIndex = active ? 0 : -1;
        });
        panes.forEach(function (pane) {
            var active = pane.id === tab.getAttribute("aria-controls");
            pane.classList.toggle("is-active", active);
            pane.hidden = !active;
        });
        if (focus) {
            tab.focus();
        }
    }

    tabs.forEach(function (tab, index) {
        tab.addEventListener("click", function () {
            selectTab(tab, false);
        });
        tab.addEventListener("keydown", function (event) {
            var next = null;
            if (event.key === "ArrowRight") {
                next = tabs[(index + 1) % tabs.length];
            } else if (event.key === "ArrowLeft") {
                next = tabs[(index - 1 + tabs.length) % tabs.length];
            } else if (event.key === "Home") {
                next = tabs[0];
            } else if (event.key === "End") {
                next = tabs[tabs.length - 1];
            }
            if (next) {
                event.preventDefault();
                selectTab(next, true);
            }
        });
    });

    if (tabs.length) {
        selectTab(tabs[0], false);
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
