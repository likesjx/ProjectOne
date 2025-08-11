# 🛠️ ProjectOne Scripts

This directory contains all shell scripts for ProjectOne development, setup, and maintenance.

## 📋 Script Index

### **🔧 Xcode & Dependency Management**
- **[cleanup_dependencies.sh](./cleanup_dependencies.sh)** - Analyze and clean up project dependencies
- **[fix_dependency_conflict.sh](./fix_dependency_conflict.sh)** - Quick fix for dependency conflicts
- **[nuclear_xcode_cleanup.sh](./nuclear_xcode_cleanup.sh)** - Complete Xcode cache cleanup (nuclear option)

### **🚀 Project Setup**
- **[setup_xcode_project.sh](./setup_xcode_project.sh)** - Automated Xcode project setup

### **🗄️ Database Management**
- **[reset_database.sh](./reset_database.sh)** - Reset SwiftData database and caches

## 🚀 Quick Start

### **For Dependency Issues:**
```bash
# Analyze current dependency state
./scripts/cleanup_dependencies.sh

# Quick fix for conflicts
./scripts/fix_dependency_conflict.sh

# Nuclear option - complete cleanup
./scripts/nuclear_xcode_cleanup.sh
```

### **For Project Setup:**
```bash
# Set up Xcode project
./scripts/setup_xcode_project.sh
```

### **For Database Reset:**
```bash
# Reset SwiftData database
./scripts/reset_database.sh
```

## 📖 Script Details

### **cleanup_dependencies.sh**
**Purpose**: Analyze current dependency state and provide cleanup recommendations
**Usage**: `./scripts/cleanup_dependencies.sh`
**Output**: Current dependency status and recommended actions

### **fix_dependency_conflict.sh**
**Purpose**: Quick fix for dependency version conflicts
**Usage**: `./scripts/fix_dependency_conflict.sh`
**Output**: Step-by-step instructions for resolving conflicts

### **nuclear_xcode_cleanup.sh**
**Purpose**: Complete Xcode cache and derived data cleanup
**Usage**: `./scripts/nuclear_xcode_cleanup.sh`
**Warning**: This will delete all Xcode caches and derived data
**Output**: Complete cleanup with fresh start instructions

### **setup_xcode_project.sh**
**Purpose**: Automated Xcode project setup with dependencies
**Usage**: `./scripts/setup_xcode_project.sh`
**Output**: Creates Xcode project with all required dependencies

### **reset_database.sh**
**Purpose**: Reset SwiftData database and clear caches
**Usage**: `./scripts/reset_database.sh`
**Warning**: This will delete all local data
**Output**: Database reset confirmation

## 🔧 Script Permissions

All scripts are executable by default. If you encounter permission issues:

```bash
# Make all scripts executable
chmod +x scripts/*.sh

# Or make individual scripts executable
chmod +x scripts/cleanup_dependencies.sh
chmod +x scripts/fix_dependency_conflict.sh
chmod +x scripts/nuclear_xcode_cleanup.sh
chmod +x scripts/setup_xcode_project.sh
chmod +x scripts/reset_database.sh
```

## 🎯 Common Use Cases

### **When Xcode is Being Stubborn:**
1. Run `nuclear_xcode_cleanup.sh` for complete cache cleanup
2. Reopen Xcode project
3. Build and test

### **When Dependencies Won't Resolve:**
1. Run `cleanup_dependencies.sh` to analyze the issue
2. Follow recommendations from the analysis
3. Use `fix_dependency_conflict.sh` for specific conflicts

### **When Database is Corrupted:**
1. Run `reset_database.sh` to clear all data
2. Restart the app
3. Re-import any necessary data

### **For Fresh Project Setup:**
1. Run `setup_xcode_project.sh` to create project
2. Add source files to Xcode
3. Build and test

## 🆘 Troubleshooting

### **Script Permission Issues:**
```bash
# Make scripts executable
chmod +x scripts/*.sh
```

### **Script Not Found:**
```bash
# Ensure you're in the project root
cd /path/to/ProjectOne
# Then run scripts
./scripts/script_name.sh
```

### **Xcode Still Having Issues:**
1. Run `nuclear_xcode_cleanup.sh`
2. Close Xcode completely
3. Reopen project
4. Clean build folder in Xcode

## 📚 Related Documentation

- **[Xcode Documentation](../docs/xcode/)** - Complete Xcode setup and dependency guides
- **[Dependency Management](../docs/xcode/DEPENDENCY_CLEANUP_ANALYSIS.md)** - Detailed dependency analysis
- **[Conflict Resolution](../docs/xcode/DEPENDENCY_CONFLICT_RESOLUTION.md)** - Dependency conflict solutions

## 🎊 Success Criteria

After running scripts, you should have:
- ✅ Clean dependency resolution
- ✅ Successful Xcode builds
- ✅ No cache conflicts
- ✅ Proper project structure
- ✅ Working database (if applicable)

## 🚨 Important Notes

- **Always backup** important data before running destructive scripts
- **Read script output** carefully for important warnings
- **Test thoroughly** after running cleanup scripts
- **Keep scripts updated** as project dependencies change

