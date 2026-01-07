# 🍳 FiroScriptsCookbook

A collection of **automation scripts** for **Proxmox LXC** and **Docker** environments.  
Each script is a “recipe” 📝 to quickly deploy containers, services, and applications.

``` 
FiroScriptsCookbook/
├─ proxmox/          # Proxmox LXC container creation scripts
├─ docker/           # Docker container setup and docker-compose recipes
└─ README.md
```

---

## 🚀 Features

- 🧱 Create and configure **Debian LXC containers** on Proxmox  
- 🐳 Install and setup **Docker** and **Portainer** inside LXC  
- 🎛️ Interactive or parameterized script execution  
- ⚡ Easily extendable: add new scripts as “recipes”  
- 📝 Colored messages, logging, and basic error handling included  

---

## 📦 Getting Started

1. **Clone the repository**:

    git clone https://github.com/firo/FiroScriptsCookbook.git  
    cd FiroScriptsCookbook

2. **List available scripts**:

    ls

3. **Run a script**:

    bash ./firo_create_lxc_docker.sh

Or pass parameters directly:

    bash ./firo_create_lxc_docker.sh <CTID> <HOSTNAME> <ROOT_PASSWORD>

---

## 🔧 Example Scripts

- `firo_create_lxc_docker.sh` – Create a Debian 12 LXC container with Docker + Portainer  
- *(More recipes coming soon! e.g., LAMP stack, PostgreSQL container, etc.)*  

---

## 🤝 Contributing

Contributions welcome! Add new recipes, improve scripts, or report issues.  

---

## 📜 License

Add your license info here (e.g., MIT License)
