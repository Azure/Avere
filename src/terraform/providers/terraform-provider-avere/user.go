// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

func (u *User) IsEqual(u2 *User) bool {
	return *u == *u2
}

func (u *User) IsEqualNoPassword(u2 *User) bool {
	return u.Name == u2.Name && u.Permission == u2.Permission
}
