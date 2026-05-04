import 'package:flutter/material.dart';

class CustomAlert {
  // Fungsi untuk menampilkan Alert (Bisa untuk Error, Sukses, dll)
  static void show(BuildContext context, String message, {bool isError = true}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding: const EdgeInsets.all(20),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline, 
              color: isError ? Colors.red : Colors.green, 
              size: 30
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                message.replaceAll("Exception: ", ""), 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Tutup", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}