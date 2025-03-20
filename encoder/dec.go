package main

import (
	"crypto/aes"
	"crypto/cipher"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
)

func main() {

	folder := "pdf"
	const aes_key = "854)?_/*5623.01><-AV85Ik*'pm2?!2" //128 bit

	err := filepath.Walk(folder, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			fmt.Println("Error accessing path:", path, err)
			return err
		}

		if !info.IsDir() && strings.HasSuffix(info.Name(), ".enc") {
			data, err := os.ReadFile(path)
			if err != nil {
				log.Println("Error reading file:", path, err)
				return err
			}

			newfilename := strings.TrimSuffix(path, ".enc")

			file, err := os.Create(newfilename)

			if err != nil {
				fmt.Println("some error", err)
			}
			defer file.Close()

			aes_key_byted := []byte(aes_key)

			aes_key_cipher, _ := aes.NewCipher(aes_key_byted)

			gcm, err := cipher.NewGCM(aes_key_cipher)
			if err != nil {
				fmt.Println("Erro through encrypting files", err)
				return err
			}

			nonce, ciphertext := data[:gcm.NonceSize()], data[gcm.NonceSize():]

			plainText, err := gcm.Open(nil, nonce, ciphertext, nil)

			if err != nil {
				fmt.Println(err)
				return err
			}

			_, err = file.Write(plainText)
			if err != nil {
				fmt.Println("Some error:", err)
			}

			err = os.Remove(path)
			if err != nil {
				fmt.Println(err)
			}
			fmt.Println("Decription succesful")
		}
		return err
	})

	if err != nil {
		fmt.Println("Error walking through files/folders", err)
		return
	}
}
