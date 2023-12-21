import 'dart:collection';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:login_test/UIs/add_book_page_final.dart';
import 'package:login_test/backend/image_helper.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:intl/intl.dart';
import 'package:login_test/backend/google_books_api.dart';
import '../book_data.dart';
import '../database/book_database.dart';
import '../user_data.dart';
import 'package:login_test/backend/update_book_backend.dart';
import 'package:login_test/backend/firebase_auth_service.dart';
import 'add_book_page.dart';

String fbemail = dotenv.env['FIREBASE_EMAIL'] ?? '';
String fbpassword = dotenv.env['FIREBASE_PASSWORD'] ?? '';

class MyLibraryPage extends StatefulWidget {
  const MyLibraryPage({super.key});

  @override
  _MyLibraryPageState createState() => _MyLibraryPageState();
}

class _MyLibraryPageState extends State<MyLibraryPage> {
  String currentQuery = '';
  int selectedCategoryIndex = 0;


  Future<List<String>> _updateCategories() async {
    final databaseHelper = DatabaseHelper();
    final List<Book> allBooks = await databaseHelper.getAllBooks();

    // Count occurrences of each category
    final Map<String, int> categoryCount = HashMap();

    for (final book in allBooks) {
        categoryCount[book.category] = (categoryCount[book.category] ?? 0) + 1;
    }

    // Sort categories based on count in descending order
    final sortedCategories = categoryCount.keys.toList()
      ..sort((a, b) => categoryCount[b]!.compareTo(categoryCount[a]!));

    // Take the top 10 categories
    List<String> categories = sortedCategories.take(10).toList();
    return categories;
  }

  @override
  void initState() {
    super.initState();
    _updateBookList();
  }

  @override
  Widget build(BuildContext context) {
    double baseWidth = 360;
    double fem = MediaQuery.of(context).size.width / baseWidth;


    return Stack(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Enter title or author',
                      ),
                      onChanged: (query) {
                        setState(() {
                          currentQuery = query;
                        });
                      },
                    ),
                  ),
                  // Search icon
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                        _updateBookList();
                    },
                  ),
                  // Stack or List icon
                  IconButton(
                    icon: const Icon(Icons.filter_alt), // You can change the icon
                    onPressed: () {
                      _showDialog(context);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 40 * fem, // Set the desired height
              child: FutureBuilder<List<String>>(
                future: _updateCategories(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('');
                  } else {
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: snapshot.data?.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8 * fem),
                          child: TextButton(
                            onPressed: () {
                              // Handle category button press
                              setState(() {
                                selectedCategoryIndex = index;
                              });
                              print('Category selected: ${snapshot.data![index]}');
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: selectedCategoryIndex == index
                                  ? Colors.black
                                  : Colors.grey, backgroundColor: Colors.transparent, // Set background color to transparent
                            ),
                            child: Text(
                              snapshot.data![index],
                              style: TextStyle(
                                fontSize: 14*fem,
                                fontWeight: selectedCategoryIndex == index
                                    ? FontWeight.bold
                                    : FontWeight.normal, // Make the selected category bold
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                },
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Book>>(
                future: _getFilteredBooksFromDatabase(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('No books found.');
                  } else {
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        return Flex(
                          direction: Axis.horizontal,
                          children: [
                            _buildBookButton(snapshot.data![index]),
                          ],
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 16.0,
          right: 16.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FloatingActionButton(
                heroTag: 'barcode scanner',
                onPressed: () {
                  // Book? book = await getBookByBarcode();
                  // if (mounted) {
                  //   if (book != null) {
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(
                  //         builder: (context) => AddBookDetailsPage(book: book),
                  //       ),
                  //     );
                  //   } else {
                  //     ScaffoldMessenger.of(context).showSnackBar(
                  //       const SnackBar(content: Text('Cannot find the book, please try another one!')),
                  //     );
                  //   }
                  // }
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                      builder: (context) => AddBookScreen(book: Book.defaultBook()),
                      ),
                  );
                },
                child: Icon(MdiIcons.barcode),
              ),
              const SizedBox(height: 16.0),
              FloatingActionButton(
                heroTag: 'manual add',
                onPressed: () {
                  _showInputDialog();
                },
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Dialog Title'),
          content: const Text('Dialog Content'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateBookList() async {
    setState(() {});
  }

  Future<List<Book>> _getFilteredBooksFromDatabase() async {
    final databaseHelper = DatabaseHelper();
    final List<Book> allBooks = await databaseHelper.getAllBooks();

    // Filter books based on the search query
    if (currentQuery.isEmpty) {
      return allBooks; // Return all books if the query is empty
    } else {
      final String queryLowerCase = currentQuery.toLowerCase();
      return allBooks.where((book) =>
      book.title.toLowerCase().contains(queryLowerCase) ||
          book.authors.any((author) => author.toLowerCase().contains(queryLowerCase))
      ).toList();
    }
  }

  String _truncateAuthorName(String authorName) {
    const maxLength = 7;

    if (authorName.length > maxLength) {
      return '${authorName.substring(0, maxLength)}...';
    } else {
      return authorName;
    }
  }

  Widget _buildBookButton(Book book) {
    double baseWidth = 360;
    double fem = MediaQuery.of(context).size.width / baseWidth;

    var bookCover = NetworkImage(book.imageLinks['thumbnail']!);
    // Implement the UI for a book button
    // You can use ElevatedButton or any other widget you prefer
    return GestureDetector(
      child: Container(
        margin: EdgeInsets.fromLTRB(10*fem,0,0,0),
        width: 150 * fem,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 250 * fem,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12 * fem),
                image: DecorationImage(
                  image: bookCover,
                  fit: BoxFit.cover,
                  onError: (context, stackTrace) => const AssetImage('assets/default-book.png'),
                ),
              ),
            ),
            SizedBox(height: 10 * fem),
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16 * fem,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              book.authors.length > 1
                  ? '${_truncateAuthorName(book.authors[0])}, ${_truncateAuthorName(book.authors[1])}'
                  : book.authors[0],
              style: TextStyle(
                fontSize: 16 * fem,
                color: Colors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showInputDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return MyDialog();
      },
    );
  }
}

class MyDialog extends StatefulWidget {
  @override
  _MyDialogState createState() => _MyDialogState();
}

class _MyDialogState extends State<MyDialog> {
  TextEditingController titleController = TextEditingController();
  TextEditingController subtitleController = TextEditingController();
  TextEditingController authorController = TextEditingController();
  TextEditingController categoryController = TextEditingController();
  TextEditingController publishedDateController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController totalPagesController = TextEditingController();
  TextEditingController languageController = TextEditingController();
  TextEditingController thumbnailController = TextEditingController();
  TextEditingController buyDateController = TextEditingController();
  TextEditingController lastPageReadController = TextEditingController();
  TextEditingController lastSeenPlaceController = TextEditingController();

  List<String> authors = [];
  List<int> years = List.generate(150, (int index) => DateTime.now().year - index);
  String? selectedLanguageCode;
  String? selectedYear;
  String? _imageUrl;
  File? _imageFile;

  final databaseHelper = DatabaseHelper();
  final provider = container.read(userProvider);

  final imageHelper = ImageHelper();

  @override
  Widget build(BuildContext context) {
    final UserData? userData = provider.user;
    return AlertDialog(
      title: const Text('Enter Book Information'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: subtitleController,
              decoration: const InputDecoration(labelText: 'Subtitle'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: authorController,
                    decoration: const InputDecoration(
                        labelText: 'Author'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    // Check if the entered author is not empty and is not already in the list
                    String newAuthor = authorController.text.trim();
                    if (newAuthor.isNotEmpty &&
                        !authors.contains(newAuthor)) {
                      setState(() {
                        authors.add(newAuthor);
                      });
                      // Clear the value of the controller
                      authorController.clear();
                    }
                  },
                ),
              ],
            ),
            Wrap(
              spacing: 8.0, // Adjust spacing as needed
              children: authors.map((author) {
                return Chip(
                  label: Text(author),
                  deleteIcon: const Icon(Icons.close),
                  onDeleted: () {
                    setState(() {
                      authors.remove(author);
                    });
                  },
                );
              }).toList(),
            ),
            Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      return bookCategories
                          .where((category) => category.toLowerCase().contains(textEditingValue.text.toLowerCase()))
                          .toList();
                    },
                    onSelected: (selectedCategory) {
                      setState(() {
                        categoryController.text = selectedCategory;
                      });
                    },
                    fieldViewBuilder: (BuildContext context, TextEditingController fieldController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                      return TextField(
                        controller: fieldController,
                        focusNode: fieldFocusNode,
                        decoration: const InputDecoration(labelText: 'Categories'),
                      );
                    },
                    optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          child: SizedBox(
                            width: double.infinity,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final String category = options.elementAt(index);
                                return ListTile(
                                  title: Text(category),
                                  onTap: () {
                                    onSelected(category);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            TextFormField(
              controller: publishedDateController,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Published Year'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Select Year'),
                      content: DropdownButton<int>(
                        value: int.tryParse(selectedYear ?? ''),
                        items: years.map((int year) {
                          return DropdownMenuItem<int>(
                            value: year,
                            child: Text(year.toString()),
                          );
                        }).toList(),
                        onChanged: (int? selectedValue) {
                          setState(() {
                            selectedYear = selectedValue?.toString();
                            publishedDateController.text = selectedYear ?? '';
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                );
              },
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextField(
              controller: totalPagesController,
              decoration: const InputDecoration(labelText: 'Total Pages'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: languageController,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Language'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Select Language'),
                      content: DropdownButton<String>(
                        value: selectedLanguageCode,
                        items: languageMap.entries.map((MapEntry<String, String> entry) {
                          return DropdownMenuItem<String>(
                            value: entry.value,
                            child: Text('${entry.key} (${entry.value})'),
                          );
                        }).toList(),
                        onChanged: (String? selectedValue) {
                          setState(() {
                            selectedLanguageCode = selectedValue;
                            languageController.text =
                            '${languageMap.keys.firstWhere((key) => languageMap[key] == selectedLanguageCode)} ($selectedLanguageCode)';
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                );
              },
            ),
            TextFormField(
              controller: buyDateController,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Buy Date'),
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (pickedDate != null) {
                  final formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
                  setState(() {
                    buyDateController.text = formattedDate; // Format the date as needed
                  });
                }
              },
            ),
            TextFormField(
              controller: lastPageReadController,
              keyboardType: TextInputType.number,
              onChanged: (_) {
                setState(() {});
              },
              decoration: InputDecoration(
                labelText: 'Last Page Read',
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: lastPageReadController.text.isNotEmpty &&
                        int.tryParse(lastPageReadController.text) != null &&
                        int.parse(lastPageReadController.text) > int.parse(totalPagesController.text)
                        ? Colors.red
                        : Colors.transparent, // Set to transparent to remove the border
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.blue,
                  ),
                ),
                errorText: lastPageReadController.text.isNotEmpty &&
                    int.tryParse(lastPageReadController.text) != null &&
                    int.parse(lastPageReadController.text) > int.parse(totalPagesController.text)
                    ? 'Value must be less than or equal to total pages'
                    : null,
              ),
            ),
            TextField(
              controller: lastSeenPlaceController,
              decoration: const InputDecoration(labelText: 'Last Seen Place'),
            ),
            ElevatedButton(
              onPressed: () async{
                final image = await imageHelper.selectImageFromGallery();
                setState(() {
                  _imageFile = image;
                });
              },
              child: const Text('Choose Image'),
            ),

            ElevatedButton(
              onPressed: () async{
                final image = await imageHelper.takePicture();
                setState(() {
                  _imageFile = image;
                });
              },
              child: const Text('Take Picture'),
            ),
            _imageFile != null ? Image.file(_imageFile!) : const Text('Please select image')
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            authors = [];
            _imageFile = null;
            Navigator.of(context).pop(false); // Close the dialog and return false
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              },
              barrierDismissible: false, // Prevent user from dismissing the dialog
            );

            final result = await addBook();

            if (mounted) {
              Navigator.of(context).pop();
            }

            if (mounted) {
              Navigator.of(context).pop(); // Close the loading dialog
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result['message'])),
              );

              if (result['message'] == 'Added book successfully') {
                print(result['message']);
                await databaseHelper.syncBooksFromServer(userData!.userId, userData.username);
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> addBook() async {
    // Upload image to Firebase Storage and get the URL
    _imageUrl = await ImageHelper.uploadImageToFirebaseStorage(fbemail, fbpassword, _imageFile!);
    final newId = generateUniqueId();
    final UserData? userData = provider.user;

    if (_imageUrl != null) {
      Book book = Book(
          id: newId,
          title: titleController.text,
          subtitle: subtitleController.text,
          authors: authors,
          category: categoryController.text,
          publishedDate: selectedYear ?? 'unk',
          description: descriptionController.text,
          totalPages: int.parse(totalPagesController.text),
          language: selectedLanguageCode ?? 'unk',
          imageLinks: {'thumbnail': _imageUrl!}
      );

      BookState bookState = BookState(
        bookId: book.id,
        buyDate: buyDateController.text,
        lastReadDate: DateTime.now(),
        lastPageRead: int.parse(lastPageReadController.text),
        percentRead: int.parse(lastPageReadController.text)/book.totalPages*100,
        totalReadHours: 0.0,
        addToFavorites: false,
        lastSeenPlace: lastSeenPlaceController.text,
        userId: userData?.userId ?? 0,
        quotation: [],
        comment: [],
      );

      final updateBackend = UpdateBookBackend();
      final bookResult = await updateBackend.addOrUpdateBook(book);
      final stateResult = await updateBackend.addBookToLibrary(bookState);

      Map<String, dynamic> result = {};
      if(bookResult['success'] && stateResult['success']) {
        result['success'] = true;
        result['message'] = 'Added book successfully';
      } else {
        result['success'] = false;
        result['message'] = stateResult['success'] ? bookResult['message'] : stateResult['message'];
      }
      return result;
    } else {
      final result = await addBook();
      return result;
    }
  }
}
