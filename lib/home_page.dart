import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

enum DrawerSection { addIdea, viewIdeas, calendar }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  DateTime selectedDate = DateTime.now();
  final TextEditingController ideaTitleController = TextEditingController();
  final TextEditingController ideaDescController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  List<Map<String, String>> allIdeas = [];
  List<Map<String, String>> displayedIdeas = [];

  @override
  void initState() {
    super.initState();
    loadIdeas();
  }

  Future<void> loadIdeas() async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final storedIdeas = prefs.getStringList(dateKey) ?? [];

    if (!mounted) return;
    setState(() {
      allIdeas = storedIdeas
          .map((item) => Map<String, String>.from(jsonDecode(item)))
          .toList();
      displayedIdeas = List.from(allIdeas);
    });
  }

  Future<void> saveIdea() async {
    if (ideaTitleController.text.isEmpty || ideaDescController.text.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final existing = prefs.getStringList(dateKey) ?? [];

    if (!mounted) return;

    if (existing.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum of 5 ideas can be added per day')),
      );
      return;
    }

    final newIdea = {
      'title': ideaTitleController.text,
      'desc': ideaDescController.text,
    };

    existing.add(jsonEncode(newIdea));
    await prefs.setStringList(dateKey, existing);

    if (!mounted) return;

    ideaTitleController.clear();
    ideaDescController.clear();
    await loadIdeas();
  }

  Future<void> deleteIdea(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);

    final updated = List<Map<String, String>>.from(allIdeas);
    updated.removeAt(index);

    final updatedEncoded =
    updated.map((item) => jsonEncode(item)).toList();
    await prefs.setStringList(dateKey, updatedEncoded);

    if (!mounted) return;
    await loadIdeas();
  }

  Future<void> editIdea(int index, String newTitle, String newDesc) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);

    final updated = List<Map<String, String>>.from(allIdeas);
    updated[index] = {'title': newTitle, 'desc': newDesc};

    final updatedEncoded =
    updated.map((item) => jsonEncode(item)).toList();
    await prefs.setStringList(dateKey, updatedEncoded);

    if (!mounted) return;
    await loadIdeas();
  }

  void showEditDialog(int index, String oldTitle, String oldDesc) {
    final titleController = TextEditingController(text: oldTitle);
    final descController = TextEditingController(text: oldDesc);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        final bottomInset = MediaQuery.of(modalCtx).viewInsets.bottom;

        // 💡 Capture pop callback safely BEFORE any async operations
        void safePop() {
          if (Navigator.of(modalCtx).canPop()) {
            Navigator.of(modalCtx).pop();
          }
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: bottomInset,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Edit Idea", style: Theme.of(modalCtx).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "New Title"),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: "New Description"),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await editIdea(index, titleController.text, descController.text);
                  safePop(); // ✅ Safe, no context after async
                },
                child: const Text("Save Changes"),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }


  void searchIdeas(String query) {
    setState(() {
      displayedIdeas = allIdeas
          .where((idea) =>
          idea['title']!.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Widget getDrawer() {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            child: Text(
              "IdeaVault Menu",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            title: const Text("Add Idea"),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            title: const Text("View Ideas"),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            title: const Text("Calendar"),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2023),
                lastDate: DateTime(2030),
              );
              if (picked != null && picked != selectedDate) {
                if (!mounted) return;
                setState(() {
                  selectedDate = picked;
                });
                await loadIdeas();
              }
              if (!mounted) return;
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void showSearchDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Search Idea by Title"),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(hintText: "Enter idea title"),
          onChanged: searchIdeas,
        ),
        actions: [
          TextButton(
            onPressed: () {
              searchController.clear();
              Navigator.pop(context);
            },
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: getDrawer(),
      appBar: AppBar(
        title: const Text("IdeaVault"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: showSearchDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: ideaTitleController,
              decoration: const InputDecoration(labelText: "Idea Title"),
            ),
            TextField(
              controller: ideaDescController,
              decoration: const InputDecoration(labelText: "Idea Description"),
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: saveIdea,
              icon: const Icon(Icons.add),
              label: const Text("Add Idea"),
            ),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Ideas on ${DateFormat('yyyy-MM-dd').format(selectedDate)}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: displayedIdeas.isEmpty
                  ? const Center(child: Text("No ideas yet!"))
                  : ListView.builder(
                itemCount: displayedIdeas.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(
                        displayedIdeas[index]['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(displayedIdeas[index]['desc'] ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.teal),
                            onPressed: () {
                              final actualIndex =
                              allIdeas.indexOf(displayedIdeas[index]);
                              showEditDialog(
                                actualIndex,
                                displayedIdeas[index]['title'] ?? '',
                                displayedIdeas[index]['desc'] ?? '',
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final actualIndex =
                              allIdeas.indexOf(displayedIdeas[index]);
                              await deleteIdea(actualIndex);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
