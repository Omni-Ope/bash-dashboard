const pptxgen = require("pptxgenjs");

const pres = new pptxgen();
pres.defineLayout({ name: "CLASS_WIDE", width: 13.333, height: 7.5 });
pres.layout = "CLASS_WIDE";
pres.author = "Estefan Ramos, Pedro Gonzales";
pres.title = "System Health Dashboard";
pres.subject = "Fedora and Ubuntu Server bash dashboard";

const C = {
  bg: "0A0A0A",
  ink: "ECE8E1",
  muted: "A8A49B",
  dim: "6B6760",
  faint: "2A2A28",
  card: "141414",
  ok: "C5DD97",
  warn: "E6C07B",
  crit: "E08A78",
};

const FONT = "Arial";
const MONO = "Consolas";

function addHeader(slide, label) {
  slide.addText("BASH DASHBOARD", {
    x: 0.5, y: 0.26, w: 4.8, h: 0.28,
    fontFace: FONT, fontSize: 12, color: C.ink, margin: 0, valign: "middle",
  });
  slide.addText(label, {
    x: 6.2, y: 0.26, w: 6.63, h: 0.28,
    fontFace: FONT, fontSize: 12, color: C.muted, margin: 0, align: "right", valign: "middle",
  });
}

function addFooter(slide, page) {
  slide.addText("SYSTEM HEALTH", {
    x: 0.5, y: 7.12, w: 4.2, h: 0.22,
    fontFace: FONT, fontSize: 11, color: C.dim, margin: 0,
  });
  slide.addText(page, {
    x: 9.2, y: 7.12, w: 3.63, h: 0.22,
    fontFace: FONT, fontSize: 11, color: C.dim, margin: 0, align: "right",
  });
}

function addCard(slide, x, y, w, h) {
  slide.addShape(pres.shapes.RECTANGLE, {
    x, y, w, h,
    fill: { color: C.card },
    line: { color: C.faint, width: 1 },
  });
}

// Slide 1 — Title
{
  const s = pres.addSlide();
  s.background = { color: C.bg };
  addHeader(s, "COURSE PROJECT");
  addFooter(s, "01  /  07");

  s.addText("LINUX ADMINISTRATION", {
    x: 0.5, y: 1.85, w: 12.3, h: 0.3,
    fontFace: FONT, fontSize: 13, color: C.muted, margin: 0,
  });
  s.addText("System Health Dashboard", {
    x: 0.5, y: 2.2, w: 12.3, h: 0.85,
    fontFace: FONT, fontSize: 44, color: C.ink, margin: 0,
  });
  s.addText("One readable view of a Fedora or Ubuntu server.", {
    x: 0.5, y: 3.15, w: 12.0, h: 0.4,
    fontFace: FONT, fontSize: 20, color: C.muted, italic: true, margin: 0,
  });

  const meta = [
    ["GROUP", "Estefan Ramos\nPedro Gonzales"],
    ["DATE", "November 24, 2026"],
    ["TIME", "8–10 minutes, then questions"],
  ];
  meta.forEach((item, i) => {
    const x = 0.5 + i * 4.15;
    s.addText(item[0], {
      x, y: 4.35, w: 3.8, h: 0.26,
      fontFace: FONT, fontSize: 12, color: C.dim, margin: 0,
    });
    s.addText(item[1], {
      x, y: 4.64, w: 3.9, h: 0.72,
      fontFace: FONT, fontSize: 16, color: C.ink, margin: 0,
    });
  });

  s.addText("System info   ·   CPU and memory   ·   Disk   ·   Processes   ·   Network   ·   Services   ·   Logins   ·   Journal errors", {
    x: 0.5, y: 6.35, w: 12.3, h: 0.4,
    fontFace: FONT, fontSize: 14, color: C.muted, margin: 0,
  });

  s.addNotes("About 30 seconds. Estefan Ramos opens. Say both names. Estefan presents the Fedora side. Pedro Gonzales presents the Ubuntu side.");
}

// Slide 2 — Goals and design
{
  const s = pres.addSlide();
  s.background = { color: C.bg };
  addHeader(s, "GOALS AND DESIGN");
  addFooter(s, "02  /  07");

  s.addText("Goals and design", {
    x: 0.5, y: 0.64, w: 12.3, h: 0.42,
    fontFace: FONT, fontSize: 32, color: C.ink, margin: 0,
  });

  addCard(s, 0.5, 1.22, 6.0, 3.55);
  addCard(s, 6.83, 1.22, 6.0, 3.55);

  s.addText("The problem", {
    x: 0.78, y: 1.4, w: 5.45, h: 0.36,
    fontFace: FONT, fontSize: 18, color: C.ink, margin: 0,
  });
  s.addText("Checking a server means uptime, free, df, ps, ip, systemctl, and journalctl. The dashboard puts those readings on one screen so the health of the host is visible in a single pass.", {
    x: 0.78, y: 1.86, w: 5.45, h: 1.45,
    fontFace: FONT, fontSize: 15, color: C.muted, margin: 0,
  });
  s.addText("The sections are the course topics: processes, filesystems, networking, services, users, and logs.", {
    x: 0.78, y: 3.4, w: 5.45, h: 1.1,
    fontFace: FONT, fontSize: 15, color: C.ink, margin: 0,
  });

  s.addText("How it is built", {
    x: 7.11, y: 1.4, w: 5.45, h: 0.36,
    fontFace: FONT, fontSize: 18, color: C.ink, margin: 0,
  });
  s.addText([
    { text: "One script, dashboard.sh, with one function per section", options: { bullet: true, breakLine: true } },
    { text: "A missing command prints a message and the run continues", options: { bullet: true, breakLine: true } },
    { text: "--watch clears and redraws every 5 seconds", options: { bullet: true, breakLine: true } },
    { text: "--log appends a plain-text snapshot", options: { bullet: true, breakLine: true } },
    { text: "dashboard.conf sets the color thresholds", options: { bullet: true } },
  ], {
    x: 7.11, y: 1.86, w: 5.45, h: 2.6,
    fontFace: FONT, fontSize: 15, color: C.muted, margin: 0, paraSpaceAfter: 8, valign: "top",
  });

  const chips = ["System info", "CPU and memory", "Disk", "Processes", "Network", "Services", "Logins", "Journal errors"];
  chips.forEach((label, i) => {
    const col = i % 4;
    const row = Math.floor(i / 4);
    const x = 0.5 + col * 3.123;
    const y = 5.12 + row * 0.72;
    s.addShape(pres.shapes.RECTANGLE, {
      x, y, w: 2.96, h: 0.58,
      fill: { color: C.card },
      line: { color: C.faint, width: 1 },
    });
    s.addText(label, {
      x, y, w: 2.96, h: 0.58,
      fontFace: FONT, fontSize: 14, color: C.ink, align: "center", valign: "middle", margin: 0,
    });
  });

  s.addNotes("Estefan Ramos. About 90 seconds. The problem is too many commands for one status check. Point at system info, CPU, memory, and disk as your sections. Pedro covers processes, network, services, logins, and logs on later slides.");
}

// Slide 3 — Fedora
{
  const s = pres.addSlide();
  s.background = { color: C.bg };
  addHeader(s, "FEDORA");
  addFooter(s, "03  /  07");

  s.addText("Fedora live demo", {
    x: 0.5, y: 0.66, w: 12.3, h: 0.46,
    fontFace: FONT, fontSize: 32, color: C.ink, margin: 0,
  });

  addCard(s, 0.5, 1.28, 6.0, 4.05);
  addCard(s, 6.83, 1.28, 6.0, 4.05);

  s.addText("Run this on the Fedora VM", {
    x: 0.78, y: 1.5, w: 5.45, h: 0.34,
    fontFace: FONT, fontSize: 16, color: C.ink, margin: 0,
  });
  s.addText("chmod +x dashboard.sh\n./dashboard.sh\n./dashboard.sh --watch", {
    x: 0.78, y: 2.0, w: 5.45, h: 1.25,
    fontFace: MONO, fontSize: 15, color: C.ok, margin: 0,
  });
  s.addText("The first detail line is the OS name from /etc/os-release. On this VM it should say Fedora. Leave --watch running so the class can see it refresh.", {
    x: 0.78, y: 3.45, w: 5.45, h: 1.85,
    fontFace: FONT, fontSize: 15, color: C.muted, margin: 0,
  });

  s.addText("Point at two rows", {
    x: 7.11, y: 1.5, w: 5.45, h: 0.34,
    fontFace: FONT, fontSize: 16, color: C.ink, margin: 0,
  });
  s.addText("CPU usage", {
    x: 7.11, y: 2.05, w: 5.45, h: 0.3,
    fontFace: FONT, fontSize: 16, color: C.ok, margin: 0,
  });
  s.addText("The bar is a quarter-second sample of /proc/stat. The script does not need mpstat or sysstat.", {
    x: 7.11, y: 2.38, w: 5.45, h: 0.78,
    fontFace: FONT, fontSize: 15, color: C.muted, margin: 0,
  });
  s.addText("Services", {
    x: 7.11, y: 3.35, w: 5.45, h: 0.3,
    fontFace: FONT, fontSize: 16, color: C.ok, margin: 0,
  });
  s.addText("Expect sshd, crond, and firewalld. Green means active. Red means the unit failed. Yellow means inactive or not installed.", {
    x: 7.11, y: 3.7, w: 5.45, h: 1.15,
    fontFace: FONT, fontSize: 15, color: C.muted, margin: 0,
  });

  s.addText("Switch to the Fedora VM for the live view. The submission screenshot has to be from that VM.", {
    x: 0.5, y: 5.55, w: 12.3, h: 1.2,
    fontFace: FONT, fontSize: 15, color: C.ink, margin: 0,
  });

  s.addNotes("Estefan Ramos. About 2 minutes, including the live switch. Show the Fedora OS line, the CPU bar, and sshd, crond, and firewalld. Those three unit names are your side of the service check. If the projector cannot show the VM, use the Fedora screenshot.");
}

// Slide 4 — Ubuntu
{
  const s = pres.addSlide();
  s.background = { color: C.bg };
  addHeader(s, "UBUNTU SERVER");
  addFooter(s, "04  /  07");

  s.addText("Ubuntu Server live demo", {
    x: 0.5, y: 0.66, w: 12.3, h: 0.42,
    fontFace: FONT, fontSize: 32, color: C.ink, margin: 0,
  });
  s.addText("Same script. The service unit names are what change.", {
    x: 0.5, y: 1.14, w: 12.3, h: 0.32,
    fontFace: FONT, fontSize: 16, color: C.muted, margin: 0,
  });

  const head = (text) => ({
    text,
    options: { fill: { color: "1D1D1B" }, color: C.ink, bold: true, align: "left", valign: "middle" },
  });
  const cell = (text) => ({
    text,
    options: { fill: { color: C.card }, color: C.ink, align: "left", valign: "middle" },
  });
  s.addTable([
    [head("Check"), head("Fedora"), head("Ubuntu Server")],
    [cell("SSH"), cell("sshd.service"), cell("ssh.service")],
    [cell("Scheduler"), cell("crond.service"), cell("cron.service")],
    [cell("Firewall"), cell("firewalld.service"), cell("ufw or nftables")],
    [cell("CPU percent"), cell("/proc/stat"), cell("/proc/stat")],
    [cell("Disk"), cell("df -h"), cell("df -h")],
    [cell("Errors"), cell("journalctl -p err"), cell("journalctl -p err")],
  ], {
    x: 0.5, y: 1.58, w: 12.33, h: 3.55,
    colW: [2.6, 4.86, 4.87],
    border: [
      { pt: 0.5, color: C.faint },
      { pt: 0.5, color: C.faint },
      { pt: 0.5, color: C.faint },
      { pt: 0.5, color: C.faint },
    ],
    fontFace: FONT,
    fontSize: 14,
    color: C.ink,
    valign: "middle",
  });

  s.addText("Inactive is yellow: the unit is installed and stopped. Not installed is also yellow, and the other sections still print. If the firewall unit is missing, the script adds systemd-journald so a real service state is still on screen.", {
    x: 0.5, y: 5.35, w: 12.33, h: 1.5,
    fontFace: FONT, fontSize: 15, color: C.muted, margin: 0,
  });

  s.addNotes("Pedro Gonzales. About 2 minutes. Run the same commands on Ubuntu Server. Point at ssh.service, cron.service, and the firewall row. Those names are your side of show_services. CPU, disk, and journalctl stay the same as Fedora. Mention inactive versus failed if ufw is installed but stopped.");
}

// Slide 5 — Code
{
  const s = pres.addSlide();
  s.background = { color: C.bg };
  addHeader(s, "CODE");
  addFooter(s, "05  /  07");

  s.addText("Code highlights", {
    x: 0.5, y: 0.66, w: 12.3, h: 0.42,
    fontFace: FONT, fontSize: 32, color: C.ink, margin: 0,
  });

  addCard(s, 0.5, 1.2, 6.0, 5.55);
  addCard(s, 6.83, 1.2, 6.0, 5.55);

  s.addText("Which unit name to ask for", {
    x: 0.72, y: 1.38, w: 5.65, h: 0.32,
    fontFace: FONT, fontSize: 15, color: C.ink, margin: 0,
  });
  s.addText(
    'case "$(os_id)" in\n' +
    "  ubuntu|debian|linuxmint|pop)\n" +
    '    check_service "SSH" ssh sshd\n' +
    '    check_service "Cron" cron crond\n' +
    '    check_service "Firewall" ufw firewalld nftables\n' +
    "    ;;\n" +
    "  *)\n" +
    '    check_service "SSH" sshd ssh\n' +
    '    check_service "Cron" crond cron\n' +
    '    check_service "Firewall" firewalld ufw nftables\n' +
    "    ;;\nesac",
    {
      x: 0.72, y: 1.78, w: 5.65, h: 3.35,
      fontFace: MONO, fontSize: 11, color: C.ok, margin: 0,
    }
  );
  s.addText("os_id reads /etc/os-release. The first name that systemctl can load is the one that gets printed. A missing unit is counted, and the run continues.", {
    x: 0.72, y: 5.25, w: 5.65, h: 1.3,
    fontFace: FONT, fontSize: 13, color: C.muted, margin: 0,
  });

  s.addText("Redraw every 5 seconds", {
    x: 7.05, y: 1.38, w: 5.55, h: 0.32,
    fontFace: FONT, fontSize: 15, color: C.ink, margin: 0,
  });
  s.addText(
    "while true; do\n" +
    "  if [[ -t 1 ]] && have_cmd clear; then\n" +
    "    clear\n" +
    "  else\n" +
    "    printf '\\033[H\\033[2J'\n" +
    "  fi\n" +
    "  emit\n" +
    "  sleep 5\ndone",
    {
      x: 7.05, y: 1.78, w: 5.55, h: 2.7,
      fontFace: MONO, fontSize: 14, color: C.ok, margin: 0,
    }
  );
  s.addText("watch_loop clears, draws, then waits. If clear is missing, it sends an ANSI clear. Ctrl+C stops the loop. Calling watch with --watch would start another copy, so the loop stays inside the script and --log still appends.", {
    x: 7.05, y: 4.65, w: 5.55, h: 1.85,
    fontFace: FONT, fontSize: 13, color: C.muted, margin: 0,
  });

  s.addNotes("Pedro Gonzales. About 90 seconds. Left snippet: you try Ubuntu names first on Ubuntu, and Fedora names first on Fedora. Right snippet: your watch loop. Do not read the code line by line. Estefan can add one sentence on the CPU sample if asked.");
}

// Slide 6 — Challenges
{
  const s = pres.addSlide();
  s.background = { color: C.bg };
  addHeader(s, "CHALLENGES");
  addFooter(s, "06  /  07");

  s.addText("Challenges and the split", {
    x: 0.5, y: 0.64, w: 12.3, h: 0.42,
    fontFace: FONT, fontSize: 32, color: C.ink, margin: 0,
  });

  const cards = [
    [C.ok, "Service names differ", "Fedora uses sshd, crond, and firewalld. Ubuntu Server uses ssh, cron, and ufw. The script tries the native name first, then the other name."],
    [C.warn, "CPU percent, no extra package", "Two reads of /proc/stat, 0.25 seconds apart. Idle includes iowait. The bar uses the thresholds in dashboard.conf."],
    [C.crit, "A missing tool must not stop the page", "have_cmd checks first. That section prints [unavailable] and the rest still render. The config file is parsed as data. It is not sourced."],
  ];
  cards.forEach((card, i) => {
    const x = 0.5 + i * 4.2;
    addCard(s, x, 1.18, 3.95, 3.05);
    s.addShape(pres.shapes.RECTANGLE, {
      x, y: 1.18, w: 0.08, h: 3.05,
      fill: { color: card[0] },
      line: { color: card[0], width: 0 },
    });
    s.addText(card[1], {
      x: x + 0.26, y: 1.34, w: 3.5, h: 0.72,
      fontFace: FONT, fontSize: 16, color: C.ink, margin: 0,
    });
    s.addText(card[2], {
      x: x + 0.26, y: 2.12, w: 3.5, h: 1.9,
      fontFace: FONT, fontSize: 13, color: C.muted, margin: 0,
    });
  });

  addCard(s, 0.5, 4.48, 12.33, 2.28);
  s.addText("Who owns which part", {
    x: 0.74, y: 4.62, w: 11.9, h: 0.32,
    fontFace: FONT, fontSize: 14, color: C.ink, margin: 0,
  });
  s.addText("Estefan Ramos  —  Fedora: system, CPU, memory, disk, sshd, crond, firewalld  —  slides 2 and 3\nPedro Gonzales  —  Ubuntu: services, processes, network, logins, logs, watch, log  —  slides 4, 5, and 6", {
    x: 0.74, y: 5.05, w: 11.9, h: 1.4,
    fontFace: FONT, fontSize: 16, color: C.muted, margin: 0,
  });

  s.addNotes("Pedro Gonzales. About 90 seconds. The service-name card is yours. Estefan can answer the CPU card if someone asks, because that sample is his. Then read the two ownership lines. Estefan: Fedora system, CPU, memory, disk, and sshd, crond, firewalld, slides 2 and 3. You: Ubuntu services, processes, network, logins, logs, watch, and --log, slides 4, 5, and 6.");
}

// Slide 7 — Close
{
  const s = pres.addSlide();
  s.background = { color: C.bg };
  addHeader(s, "CLOSE");
  addFooter(s, "07  /  07");

  s.addText("Questions", {
    x: 0.5, y: 0.7, w: 12.3, h: 0.7,
    fontFace: FONT, fontSize: 44, color: C.ink, margin: 0,
  });
  s.addText("Eight sections, both course VMs, and the run continues when a command is missing.", {
    x: 0.5, y: 1.5, w: 12.3, h: 0.4,
    fontFace: FONT, fontSize: 16, color: C.muted, margin: 0,
  });

  const feats = [
    [C.ok, "8 sections"],
    [C.ok, "--watch"],
    [C.ok, "--log"],
    [C.warn, "Thresholds"],
    [C.ok, "Fedora"],
    [C.ok, "Ubuntu Server"],
  ];
  feats.forEach((feat, i) => {
    const x = 0.5 + (i % 3) * 4.2;
    const y = 2.15 + Math.floor(i / 3) * 0.85;
    s.addShape(pres.shapes.RECTANGLE, {
      x, y, w: 0.12, h: 0.55,
      fill: { color: feat[0] },
      line: { color: feat[0], width: 0 },
    });
    s.addText(feat[1], {
      x: x + 0.3, y, w: 3.5, h: 0.55,
      fontFace: FONT, fontSize: 20, color: C.ink, margin: 0, valign: "middle",
    });
  });

  s.addText("Files:  dashboard.sh    dashboard.conf    README.md    this deck\nFolder:  Documents\\bash-dashboard", {
    x: 0.5, y: 4.15, w: 12.3, h: 0.75,
    fontFace: FONT, fontSize: 16, color: C.muted, margin: 0,
  });
  s.addText("Each person should be ready to answer a question about the section they presented.", {
    x: 0.5, y: 5.2, w: 12.3, h: 0.7,
    fontFace: FONT, fontSize: 16, color: C.ink, margin: 0,
  });

  s.addNotes("About 30 seconds, then stop. Leave 2 to 3 minutes for questions. If a question is about services, logins, or the watch loop, the person who presented that part should answer. Repo path is Documents\\bash-dashboard on this machine. Screenshots still need to be taken on the Fedora VM and the Ubuntu Server VM.");
}

pres.writeFile({ fileName: "C:/Users/eramo/Documents/bash-dashboard/Bash-Dashboard-Presentation.pptx" })
  .then(() => console.log("wrote pptx"))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
