(() => {
  const input = document.getElementById("tag-search");
  const tagList = document.getElementById("tag-search-results");
  const empty = document.getElementById("tag-search-empty");

  if (!input || !tagList || !empty) return;

  const anchors = Array.from(tagList.querySelectorAll("a")).map((anchor) =>
    anchor.cloneNode(true),
  );
  tagList.innerHTML = "";

  const items = anchors.map((anchor) => {
    const li = document.createElement("li");
    li.className = "tag-item";
    li.appendChild(anchor);
    tagList.appendChild(li);
    return li;
  });

  const filter = () => {
    const q = input.value.trim().toLowerCase();
    let count = 0;
    items.forEach((item) => {
      const text = (item.textContent || "").toLowerCase();
      const matched = q.length === 0 || text.includes(q);
      item.hidden = !matched;
      if (matched) count += 1;
    });
    empty.hidden = count !== 0;
  };

  input.addEventListener("input", filter);
  filter();
})();
