<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminUserManagementTest extends TestCase
{
    use RefreshDatabase;

    private function actingAsAdmin(): User
    {
        return User::factory()->create([
            'role' => 'admin',
            'password' => 'Password123!',
        ]);
    }

    public function test_admin_can_list_users(): void
    {
        $admin = $this->actingAsAdmin();
        User::factory()->count(3)->create();

        Sanctum::actingAs($admin);

        $response = $this->getJson('/api/users');

        $response->assertOk()
            ->assertJsonStructure([
                'data' => [
                    '*' => ['id', 'name', 'email', 'role', 'created_at'],
                ],
                'meta' => ['current_page', 'last_page', 'per_page', 'total'],
            ]);
    }

    public function test_non_admin_cannot_list_users(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $this->getJson('/api/users')->assertForbidden();
    }

    public function test_admin_can_create_user(): void
    {
        $admin = $this->actingAsAdmin();

        Sanctum::actingAs($admin);

        $payload = [
            'name' => 'New Member',
            'email' => 'new-member@example.com',
            'password' => 'Password123!',
            'role' => 'user',
            'phone' => '0123456789',
            'dob' => now()->subYears(20)->toDateString(),
            'gender' => 'other',
            'accepted_terms' => true,
        ];

        $response = $this->postJson('/api/users', $payload);

        $response->assertCreated()
            ->assertJsonPath('data.email', 'new-member@example.com')
            ->assertJsonPath('data.role', 'user');

        $this->assertDatabaseHas('users', [
            'email' => 'new-member@example.com',
            'role' => 'user',
        ]);
    }

    public function test_admin_can_update_user(): void
    {
        $admin = $this->actingAsAdmin();
        $target = User::factory()->create([
            'role' => 'user',
            'password' => 'Password123!',
        ]);

        Sanctum::actingAs($admin);

        $payload = [
            'name' => 'Updated Name',
            'role' => 'admin',
            'password' => 'Password123!',
            'accepted_terms' => false,
        ];

        $response = $this->putJson("/api/users/{$target->id}", $payload);

        $response->assertOk()
            ->assertJsonPath('data.name', 'Updated Name')
            ->assertJsonPath('data.role', 'admin');

        $this->assertDatabaseHas('users', [
            'id' => $target->id,
            'name' => 'Updated Name',
            'role' => 'admin',
        ]);
    }

    public function test_admin_can_delete_other_user_but_not_self(): void
    {
        $admin = $this->actingAsAdmin();
        $other = User::factory()->create();

        Sanctum::actingAs($admin);

        $this->deleteJson("/api/users/{$admin->id}")
            ->assertStatus(422);

        $this->deleteJson("/api/users/{$other->id}")
            ->assertOk()
            ->assertJsonPath('message', 'User deleted');

        $this->assertDatabaseMissing('users', ['id' => $other->id]);
    }
}
