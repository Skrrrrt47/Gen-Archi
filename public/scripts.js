// Fetch existing data on load
fetch("/data")
  .then((response) => response.json())
  .then((data) => {
    const dataList = document.getElementById("dataList");
    data.forEach((item) => {
      const li = document.createElement("li");
      li.textContent = item.name;
      dataList.appendChild(li);
    });
  });

// Form submit handler
document
  .getElementById("dataForm")
  .addEventListener("submit", function (event) {
    event.preventDefault();
    const name = document.getElementById("name").value;

    fetch("/data", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ name }),
    })
      .then((response) => response.json())
      .then((data) => {
        const li = document.createElement("li");
        li.textContent = data.name;
        document.getElementById("dataList").appendChild(li);
      });

    document.getElementById("name").value = "";
  });
