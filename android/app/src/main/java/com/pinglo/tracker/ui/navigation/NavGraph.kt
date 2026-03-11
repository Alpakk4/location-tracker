package com.pinglo.tracker.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.pinglo.tracker.ui.diary.DiaryDayDetailScreen
import com.pinglo.tracker.ui.diary.DiaryScreen
import com.pinglo.tracker.ui.onboarding.OnboardingScreen
import com.pinglo.tracker.ui.tracker.TrackerScreen
import com.pinglo.tracker.ui.welcome.WelcomeScreen

object Routes {
    const val WELCOME = "welcome"
    const val ONBOARDING = "onboarding"
    const val MAIN = "main"
    const val TRACKER = "tracker"
    const val DIARY = "diary"
    const val DIARY_DETAIL = "diary/{date}"

    fun diaryDetail(date: String) = "diary/$date"
}

enum class BottomTab(
    val route: String,
    val label: String,
    val icon: ImageVector,
) {
    Tracker(Routes.TRACKER, "Tracker", Icons.Filled.LocationOn),
    Diary(Routes.DIARY, "Diary", Icons.Filled.DateRange),
}

@Composable
fun PingloNavHost(modifier: Modifier = Modifier) {
    val rootNavController = rememberNavController()

    NavHost(
        navController = rootNavController,
        startDestination = Routes.WELCOME,
        modifier = modifier,
    ) {
        composable(Routes.WELCOME) {
            WelcomeScreen(
                onFinished = { hasCompletedOnboarding ->
                    val dest = if (hasCompletedOnboarding) Routes.MAIN else Routes.ONBOARDING
                    rootNavController.navigate(dest) {
                        popUpTo(Routes.WELCOME) { inclusive = true }
                    }
                },
            )
        }

        composable(Routes.ONBOARDING) {
            OnboardingScreen(
                onComplete = {
                    rootNavController.navigate(Routes.MAIN) {
                        popUpTo(Routes.ONBOARDING) { inclusive = true }
                    }
                },
            )
        }

        composable(Routes.MAIN) {
            MainTabScreen()
        }
    }
}

@Composable
private fun MainTabScreen() {
    val tabNavController = rememberNavController()
    val navBackStackEntry by tabNavController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    Scaffold(
        bottomBar = {
            NavigationBar {
                BottomTab.entries.forEach { tab ->
                    val selected = when (tab) {
                        BottomTab.Tracker -> currentRoute == tab.route
                        BottomTab.Diary -> currentRoute == tab.route || currentRoute == Routes.DIARY_DETAIL
                    }
                    NavigationBarItem(
                        selected = selected,
                        onClick = {
                            tabNavController.navigate(tab.route) {
                                popUpTo(tabNavController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = { Icon(tab.icon, contentDescription = tab.label) },
                        label = { Text(tab.label) },
                    )
                }
            }
        },
    ) { innerPadding ->
        NavHost(
            navController = tabNavController,
            startDestination = BottomTab.Tracker.route,
            modifier = Modifier.padding(innerPadding),
        ) {
            composable(BottomTab.Tracker.route) {
                TrackerScreen()
            }

            composable(BottomTab.Diary.route) {
                DiaryScreen(
                    onDaySelected = { date ->
                        tabNavController.navigate(Routes.diaryDetail(date))
                    },
                )
            }

            composable(
                route = Routes.DIARY_DETAIL,
                arguments = listOf(navArgument("date") { type = NavType.StringType }),
            ) { backStackEntry ->
                val date = backStackEntry.arguments?.getString("date") ?: return@composable
                DiaryDayDetailScreen(
                    date = date,
                    onBack = { tabNavController.popBackStack() },
                )
            }
        }
    }
}
